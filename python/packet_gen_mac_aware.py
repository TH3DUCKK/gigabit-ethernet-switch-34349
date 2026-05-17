import os
import random
import zlib
import struct
from scapy.all import Ether, IP, UDP, Raw, raw

class SwitchTestGenerator:
    def __init__(self, num_ports=4, num_vectors=100, output_dir="test_vectors"):
        self.num_ports = min(num_ports, 4) 
        self.num_vectors = num_vectors
        self.output_dir = output_dir
        
        # ---------------------------------------------------------
        # Time and MAC State Tracking
        # ---------------------------------------------------------
        self.current_cycle = 0
        self.mac_table = {}       # Known learned MACs: mac -> port
        self.learning_queue = {}  # MACs currently in the arbiter/FIFO: mac -> (port, ready_cycle)
        
        # Worst-case latency: 4 ports * 7 cycles + 4 cycles arbiter overhead
        self.MAX_LEARN_CYCLES = 32 
        
        self.macs = [f"00:00:00:00:00:0{i}" for i in range(self.num_ports)]
        
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)

    def reset_state(self):
        """Clears time and switch memory for a new test."""
        self.current_cycle = 0
        self.mac_table = {}
        self.learning_queue = {}

    def _advance_time(self, cycles):
        """Advances the internal clock and promotes learned MACs."""
        self.current_cycle += cycles
        
        # Check if any MACs in the learning queue have finished their worst-case latency
        macs_to_promote = []
        for mac, (port, ready_cycle) in self.learning_queue.items():
            if self.current_cycle >= ready_cycle:
                self.mac_table[mac] = port
                macs_to_promote.append(mac)
                
        # Remove them from the pending queue
        for mac in macs_to_promote:
            del self.learning_queue[mac]

    def _write_packet(self, file_handle, port, delay_cycles, pkt, corrupt=False):
        if port >= self.num_ports: return
        
        # 1. Advance the simulation clock based on the delay to this packet
        self._advance_time(delay_cycles)
        
        src_mac = pkt[Ether].src
        dst_mac = pkt[Ether].dst
        
        # 2. Determine Expected Egress Port
        if dst_mac == "ff:ff:ff:ff:ff:ff":
            expected_port = 4 # Broadcast
        elif dst_mac in self.mac_table:
            expected_port = self.mac_table[dst_mac] # Definitely Unicast
        elif dst_mac in self.learning_queue:
            expected_port = 5 # DON'T CARE - It's stuck in the Arbiter/FIFO
        else:
            expected_port = 4 # Definitely Broadcast (Unknown)

        if corrupt:
            expected_port = 6 # EXPECT DROP

        # 3. Handle Source MAC Learning Logic
        if src_mac not in self.mac_table and src_mac not in self.learning_queue:
            # Put it in the queue with a worst-case ready time
            ready_cycle = self.current_cycle + self.MAX_LEARN_CYCLES
            self.learning_queue[src_mac] = (port, ready_cycle)
        elif src_mac in self.mac_table and self.mac_table[src_mac] != port:
            # MAC moved to a new port! (Optional: handle this if your switch supports it)
            ready_cycle = self.current_cycle + self.MAX_LEARN_CYCLES
            self.learning_queue[src_mac] = (port, ready_cycle)
            del self.mac_table[src_mac]

        # 4. Calculate FCS and Assemble Physical Packet
        raw_bytes = raw(pkt)
        #crc = zlib.crc32(raw_bytes) & 0xffffffff
        crc = self.custom_crc32_msb(raw_bytes)
        fcs_bytes = struct.pack('>I', crc)

        preamble_sfd = b'\x55\x55\x55\x55\x55\x55\x55\xD5'
        final_packet_bytes = preamble_sfd + raw_bytes + fcs_bytes
        
        if corrupt:
            final_packet_bytes = bytearray(final_packet_bytes)
            final_packet_bytes[-1] ^= 0xFF 
            
        hex_data = final_packet_bytes.hex()
        
        # 5. Write to file
        file_handle.write(f"{port} {delay_cycles} {expected_port} {hex_data}\n")
        
        # 6. Advance clock to account for the packet actually transmitting over the wire
        # (Assuming 1 byte per clock cycle on your GMII interface)
        packet_tx_cycles = len(final_packet_bytes)
        self._advance_time(packet_tx_cycles)

    def _build_packet(self, src_mac, dst_mac, size=64):
        pkt = Ether(src=src_mac, dst=dst_mac) / IP(src="192.168.0.1", dst="192.168.0.2") / UDP(sport=1234, dport=5678)
        current_len = len(pkt)
        pad_len = size - current_len - 4 
        if pad_len > 0:
            pkt = pkt / Raw(load=b'\xAA' * pad_len)
        return pkt

    def custom_crc32_msb(self, raw_bytes):
            """
            Init: 0xFFFFFFFF
            Poly: 0x04C11DB7 
            Final XOR: 0xFFFFFFFF
            Data processed MSB first (Non-Reflected)
            """
            crc = 0xFFFFFFFF
            poly = 0x04C11DB7
            
            for byte in raw_bytes:
                crc ^= (byte << 24)
                for _ in range(8):
                    if crc & 0x80000000:
                        crc = ((crc << 1) ^ poly) & 0xFFFFFFFF
                    else:
                        crc = (crc << 1) & 0xFFFFFFFF
                        
            return crc ^ 0xFFFFFFFF

    # ==========================================
    # TEST VECTOR GENERATION METHODS
    # ==========================================
    # (The test methods remain largely the same, but call self.reset_state() at the start)

    def test_standard_transmission(self):
        self.reset_state()
        filename = os.path.join(self.output_dir, "test_standard_transmission.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for _ in range(5):
                pkt = self._build_packet(self.macs[0], self.macs[1], size=64)
                # Ample delay (100) ensures learning finishes before next packet
                self._write_packet(f, port=0, delay_cycles=100, pkt=pkt)

    def test_simultaneous_arrival(self):
        self.reset_state()
        filename = os.path.join(self.output_dir, "test_simultaneous_arrival.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for _ in range(5):
                # Blast 4 packets at the exact same time
                for p in range(self.num_ports):
                    dst_port = (p + 1) % self.num_ports
                    pkt = self._build_packet(self.macs[p], self.macs[dst_port])
                    self._write_packet(f, port=p, delay_cycles=0, pkt=pkt)
                
                # Wait 100 cycles to let the arbiter and learning queue settle completely
                self._write_packet(f, port=0, delay_cycles=100, pkt=self._build_packet(self.macs[0], self.macs[1]))

    def test_multiple_ports(self):
        self.reset_state()
        filename = os.path.join(self.output_dir, "test_multiple_ports.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for p in range(self.num_ports):
                dst_port = (p + 1) % self.num_ports
                pkt = self._build_packet(self.macs[p], self.macs[dst_port])
                self._write_packet(f, port=p, delay_cycles=100, pkt=pkt)
            
                # Wait 100 cycles to let the arbiter and learning queue settle completely
                self._write_packet(f, port=0, delay_cycles=100, pkt=self._build_packet(self.macs[0], self.macs[1]))

    def test_back_to_back(self):
        filename = os.path.join(self.output_dir, "test_back_to_back.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for _ in range(10):
                pkt = self._build_packet(self.macs[0], self.macs[1], size=128)
                self._write_packet(f, port=0, delay_cycles=0, pkt=pkt)

    def test_mac_learning(self):
        filename = os.path.join(self.output_dir, "test_mac_learning.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            # 1. Port 0 sends to Port 1 (Broadcast)
            pkt1 = self._build_packet(self.macs[0], self.macs[1])
            self._write_packet(f, port=0, delay_cycles=200, pkt=pkt1)
            
            # 2. Port 1 replies to Port 0 (Switch learns)
            pkt2 = self._build_packet(self.macs[1], self.macs[0])
            self._write_packet(f, port=1, delay_cycles=200, pkt=pkt2)
            
            # 3. Port 0 sends to Port 1 again (Unicast)
            pkt3 = self._build_packet(self.macs[0], self.macs[1])
            self._write_packet(f, port=0, delay_cycles=200, pkt=pkt3)

    def test_errors(self):
        filename = os.path.join(self.output_dir, "test_errors.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for i in range(10):
                pkt = self._build_packet(self.macs[0], self.macs[1], size=64)
                is_corrupt = (i % 3 == 0)
                self._write_packet(f, port=0, delay_cycles=50, pkt=pkt, corrupt=is_corrupt)

    def test_congestion(self):
        filename = os.path.join(self.output_dir, "test_congestion.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for _ in range(self.num_vectors // 4):
                for p in range(1, self.num_ports):
                    pkt = self._build_packet(self.macs[p], self.macs[0], size=256)
                    self._write_packet(f, port=p, delay_cycles=0, pkt=pkt)

    def test_heavy_load(self):
        filename = os.path.join(self.output_dir, "test_heavy_load.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for _ in range(self.num_vectors):
                src_p = random.randint(0, self.num_ports - 1)
                dst_p = random.randint(0, self.num_ports - 1)
                while dst_p == src_p: dst_p = random.randint(0, self.num_ports - 1)
                
                pkt = self._build_packet(self.macs[src_p], self.macs[dst_p], size=random.randint(64, 512))
                self._write_packet(f, port=src_p, delay_cycles=random.randint(0, 5), pkt=pkt)

    def test_fifo_fill_big_packets(self):
        filename = os.path.join(self.output_dir, "test_fifo_fill_big_packets.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for _ in range(self.num_vectors // 2):
                pkt = self._build_packet(self.macs[0], self.macs[1], size=1518)
                self._write_packet(f, port=0, delay_cycles=0, pkt=pkt)

    def test_packet_sizes(self):
        filename = os.path.join(self.output_dir, "test_packet_sizes.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for _ in range(20):
                size = 1518 if random.random() < 0.9 else 64
                pkt = self._build_packet(self.macs[0], self.macs[1], size=size)
                self._write_packet(f, port=0, delay_cycles=10, pkt=pkt)
                
            for _ in range(20):
                size = 64 if random.random() < 0.9 else 1518
                pkt = self._build_packet(self.macs[1], self.macs[0], size=size)
                self._write_packet(f, port=1, delay_cycles=10, pkt=pkt)

    def test_unique_macs(self):
        filename = os.path.join(self.output_dir, "test_unique_macs.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for i in range(self.num_vectors):
                unique_src = f"0A:00:00:00:{i//256:02x}:{i%256:02x}"
                unique_dst = f"0B:00:00:00:{i//256:02x}:{i%256:02x}"
                pkt = self._build_packet(unique_src, unique_dst)
                port = i % self.num_ports
                self._write_packet(f, port=port, delay_cycles=20, pkt=pkt)

    def test_congestion(self):
        filename = os.path.join(self.output_dir, "test_congestion.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for _ in range(self.num_vectors // 4):
                for p in range(1, self.num_ports):
                    pkt = self._build_packet(self.macs[p], self.macs[0], size=256)
                    self._write_packet(f, port=p, delay_cycles=0, pkt=pkt)

    def test_heavy_load(self):
        filename = os.path.join(self.output_dir, "test_heavy_load.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for _ in range(self.num_vectors):
                src_p = random.randint(0, self.num_ports - 1)
                dst_p = random.randint(0, self.num_ports - 1)
                while dst_p == src_p: dst_p = random.randint(0, self.num_ports - 1)
                
                pkt = self._build_packet(self.macs[src_p], self.macs[dst_p], size=random.randint(64, 512))
                self._write_packet(f, port=src_p, delay_cycles=random.randint(0, 5), pkt=pkt)

    def test_fifo_fill_big_packets(self):
        filename = os.path.join(self.output_dir, "test_fifo_fill_big_packets.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for _ in range(self.num_vectors // 2):
                pkt = self._build_packet(self.macs[0], self.macs[1], size=1518)
                self._write_packet(f, port=0, delay_cycles=0, pkt=pkt)

    def test_packet_sizes(self):
        filename = os.path.join(self.output_dir, "test_packet_sizes.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for _ in range(20):
                size = 1518 if random.random() < 0.9 else 64
                pkt = self._build_packet(self.macs[0], self.macs[1], size=size)
                self._write_packet(f, port=0, delay_cycles=10, pkt=pkt)
                
            for _ in range(20):
                size = 64 if random.random() < 0.9 else 1518
                pkt = self._build_packet(self.macs[1], self.macs[0], size=size)
                self._write_packet(f, port=1, delay_cycles=10, pkt=pkt)

    def test_unique_macs(self):
        filename = os.path.join(self.output_dir, "test_unique_macs.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for i in range(self.num_vectors):
                unique_src = f"0A:00:00:00:{i//256:02x}:{i%256:02x}"
                unique_dst = f"0B:00:00:00:{i//256:02x}:{i%256:02x}"
                pkt = self._build_packet(unique_src, unique_dst)
                port = i % self.num_ports
                self._write_packet(f, port=port, delay_cycles=20, pkt=pkt)
    
if __name__ == "__main__":
    generator = SwitchTestGenerator()
    generator.test_standard_transmission() # PASSING
    generator.test_back_to_back()
    generator.test_mac_learning() # 
    generator.test_errors()
    generator.test_simultaneous_arrival()
    generator.test_multiple_ports()
    generator.test_congestion()
    generator.test_heavy_load()
    generator.test_unique_macs()
    generator.test_fifo_fill_big_packets()
    generator.test_packet_sizes()
    
    print("Format: <PORT_IN> <DELAY_CYCLES> <EXPECTED_PORT_OUT> <PACKET_HEX>")
    print("Expected: 0-3 (Unicast), 4 (Broadcast), 5 (DON'T CARE - Uncertainty Window)")