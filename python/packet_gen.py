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
        
        # Base MAC addresses for our ports
        self.macs = [f"00:00:00:00:00:0{i}" for i in range(self.num_ports)]
        
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)

    def _write_packet(self, file_handle, port, delay_cycles, pkt, corrupt=False):
        """Calculates FCS, handles corruption, and writes to the provided file handle"""
        if port >= self.num_ports: return
        
        # 1. Get raw bytes and calculate FCS (CRC32)
        raw_bytes = raw(pkt)
        crc = zlib.crc32(raw_bytes) & 0xffffffff
        fcs_bytes = struct.pack('<I', crc)

        preamble_sfd = b'\x55\x55\x55\x55\x55\x55\x55\xD5'

        final_packet_bytes = preamble_sfd + raw_bytes + fcs_bytes
        
        # 2. Handle intentional errors
        if corrupt:
            final_packet_bytes = bytearray(final_packet_bytes)
            final_packet_bytes[-1] ^= 0xFF # Flip bits in the FCS byte
            
        # 3. Convert to hex
        hex_data = final_packet_bytes.hex()
        
        # 4. Write new format: <PORT> <DELAY> <HEX_DATA>
        file_handle.write(f"{port} {delay_cycles} {hex_data}\n")

    def _build_packet(self, src_mac, dst_mac, size=64):
        """Builds an Ethernet packet padded to a specific size"""
        pkt = Ether(src=src_mac, dst=dst_mac) / IP(src="192.168.0.1", dst="192.168.0.2") / UDP(sport=1234, dport=5678)
        current_len = len(pkt)
        pad_len = size - current_len - 4 # Subtract 4 for the FCS we add later
        if pad_len > 0:
            pkt = pkt / Raw(load=b'\xAA' * pad_len)
        return pkt

    # ==========================================
    # TEST VECTOR GENERATION METHODS
    # ==========================================

    def test_standard_transmission(self):
        filename = os.path.join(self.output_dir, "test_standard_transmission.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for _ in range(5):
                pkt = self._build_packet(self.macs[0], self.macs[1], size=64)
                self._write_packet(f, port=0, delay_cycles=100, pkt=pkt)

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

    def test_simultaneous_arrival(self):
        filename = os.path.join(self.output_dir, "test_simultaneous_arrival.txt")
        print(f"Generating: {filename}...")
        with open(filename, 'w') as f:
            for _ in range(5):
                for p in range(self.num_ports):
                    dst_port = (p + 1) % self.num_ports
                    pkt = self._build_packet(self.macs[p], self.macs[dst_port])
                    # 0 delay between these writes means the VHDL sequencer reads them back-to-back 
                    # and should dispatch them to the port drivers simultaneously
                    self._write_packet(f, port=p, delay_cycles=0, pkt=pkt)
                # Add delay after the batch is fired
                self._write_packet(f, port=0, delay_cycles=100, pkt=self._build_packet(self.macs[0], self.macs[1]))

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
    generator = SwitchTestGenerator(num_ports=4, num_vectors=100)
    
    generator.test_standard_transmission()
    generator.test_back_to_back()
    generator.test_mac_learning()
    generator.test_errors()
    generator.test_simultaneous_arrival()
    generator.test_congestion()
    generator.test_heavy_load()
    generator.test_fifo_fill_big_packets()
    generator.test_packet_sizes()
    generator.test_unique_macs()
    
    print("Structure is as following: <PORT_NUMBER> <DELAY_IN_CYCLES> <PACKET_HEX_STRING>")
    print("Generation complete.")