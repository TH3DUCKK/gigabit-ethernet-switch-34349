import os
import random
from scapy.all import Ether, IP, UDP, Raw, raw

class SwitchTestGenerator:
    def __init__(self, num_ports=4, num_vectors=100, output_dir="test_vectors"):
        self.num_ports = min(num_ports, 4) # Max 4 as requested
        self.num_vectors = num_vectors
        self.output_dir = output_dir
        self.port_files = {}
        
        # Base MAC addresses for our ports (e.g., 00:00:00:00:00:0X)
        self.macs = [f"00:00:00:00:00:0{i}" for i in range(self.num_ports)]
        
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)
            
        # Open files for writing
        for i in range(self.num_ports):
            filepath = os.path.join(self.output_dir, f"port_{i}_stimulus.txt")
            self.port_files[i] = open(filepath, 'w')

    def __del__(self):
        for f in self.port_files.values():
            f.close()

    def _write_packet(self, port, delay_cycles, pkt, corrupt=False):
        """Helper to write a packet to a specific port's file"""
        if port >= self.num_ports: return
        
        # Convert Scapy packet to raw bytes, then to hex string
        hex_data = raw(pkt).hex()
        
        if corrupt:
            # Corrupt the last byte (simulating bad FCS/payload)
            bad_byte = format(int(hex_data[-2:], 16) ^ 0xFF, '02x')
            hex_data = hex_data[:-2] + bad_byte
            
        self.port_files[port].write(f"{delay_cycles} {hex_data}\n")

    def _build_packet(self, src_mac, dst_mac, size=64):
        """Builds an Ethernet packet of a specific size"""
        # Base packet: Ether / IP / UDP
        pkt = Ether(src=src_mac, dst=dst_mac) / IP(src="192.168.0.1", dst="192.168.0.2") / UDP(sport=1234, dport=5678)
        
        # Calculate padding needed to reach desired size (subtracting 4 bytes for Ethernet FCS)
        current_len = len(pkt)
        pad_len = size - current_len - 4 
        if pad_len > 0:
            pkt = pkt / Raw(load=b'\xAA' * pad_len)
        return pkt

    # ==========================================
    # TEST VECTOR GENERATION METHODS
    # ==========================================

    def test_standard_transmission(self):
        """Standard packet transmission from port 0 to port 1"""
        print("Generating: Standard transmission...")
        for _ in range(5):
            pkt = self._build_packet(self.macs[0], self.macs[1], size=64)
            self._write_packet(port=0, delay_cycles=100, pkt=pkt)

    def test_back_to_back(self):
        """Check for correct handling of back-to-back packets (0 delay)"""
        print("Generating: Back-to-back packets...")
        for _ in range(10):
            pkt = self._build_packet(self.macs[0], self.macs[1], size=128)
            self._write_packet(port=0, delay_cycles=0, pkt=pkt) # 0 delay

    def test_mac_learning(self):
        """Check if MAC learning works (stops broadcasting)"""
        print("Generating: MAC learning sequence...")
        # 1. Port 0 sends to Port 1 (Switch doesn't know Port 1, should broadcast)
        pkt1 = self._build_packet(self.macs[0], self.macs[1])
        self._write_packet(port=0, delay_cycles=200, pkt=pkt1)
        
        # 2. Port 1 replies to Port 0 (Switch learns Port 1)
        pkt2 = self._build_packet(self.macs[1], self.macs[0])
        self._write_packet(port=1, delay_cycles=200, pkt=pkt2)
        
        # 3. Port 0 sends to Port 1 again (Switch should unicast, not broadcast)
        pkt3 = self._build_packet(self.macs[0], self.macs[1])
        self._write_packet(port=0, delay_cycles=200, pkt=pkt3)

    def test_errors(self):
        """Check handling of packets with errors, mixed with good packets"""
        print("Generating: Error handling...")
        for i in range(10):
            pkt = self._build_packet(self.macs[0], self.macs[1], size=64)
            # Every 3rd packet is corrupted
            is_corrupt = (i % 3 == 0)
            self._write_packet(port=0, delay_cycles=50, pkt=pkt, corrupt=is_corrupt)

    def test_simultaneous_arrival(self):
        """Check for packets coming in at the same time on multiple ports"""
        print("Generating: Simultaneous arrival...")
        for _ in range(5):
            # Write to all ports with the exact same delay so the VHDL TB triggers them together
            for p in range(self.num_ports):
                dst_port = (p + 1) % self.num_ports
                pkt = self._build_packet(self.macs[p], self.macs[dst_port])
                self._write_packet(port=p, delay_cycles=100, pkt=pkt)

    def test_congestion(self):
        """Check for congestion (overloading port 0)"""
        print("Generating: Congestion (All to Port 0)...")
        # Ports 1, 2, and 3 all blast packets back-to-back at Port 0
        for _ in range(self.num_vectors // 4):
            for p in range(1, self.num_ports):
                pkt = self._build_packet(self.macs[p], self.macs[0], size=256)
                self._write_packet(port=p, delay_cycles=0, pkt=pkt)

    def test_heavy_load(self):
        """Lots of packets from lots of ports randomly"""
        print("Generating: Heavy random load...")
        for _ in range(self.num_vectors):
            src_p = random.randint(0, self.num_ports - 1)
            dst_p = random.randint(0, self.num_ports - 1)
            while dst_p == src_p: dst_p = random.randint(0, self.num_ports - 1) # Don't send to self
            
            pkt = self._build_packet(self.macs[src_p], self.macs[dst_p], size=random.randint(64, 512))
            # Minimal random delays to simulate heavy asynchronous traffic
            self._write_packet(port=src_p, delay_cycles=random.randint(0, 5), pkt=pkt)

    def test_fifo_fill_big_packets(self):
        """Check for handling of FIFO filling up (back-to-back max size packets)"""
        print("Generating: FIFO fill (Max size packets)...")
        for _ in range(self.num_vectors // 2):
            pkt = self._build_packet(self.macs[0], self.macs[1], size=1518) # Max standard Ethernet size
            self._write_packet(port=0, delay_cycles=0, pkt=pkt)

    def test_packet_sizes(self):
        """Check for primarily big and primarily small packets"""
        print("Generating: Primarily big / small packets...")
        # Primarily Big (90% big, 10% small)
        for _ in range(20):
            size = 1518 if random.random() < 0.9 else 64
            pkt = self._build_packet(self.macs[0], self.macs[1], size=size)
            self._write_packet(port=0, delay_cycles=10, pkt=pkt)
            
        # Primarily Small (90% small, 10% big)
        for _ in range(20):
            size = 64 if random.random() < 0.9 else 1518
            pkt = self._build_packet(self.macs[1], self.macs[0], size=size)
            self._write_packet(port=1, delay_cycles=10, pkt=pkt)

    def test_unique_macs(self):
        """Edge case: completely unique MAC addresses in every packet (thrashing the MAC table)"""
        print("Generating: Unique MAC addresses (Table thrashing)...")
        for i in range(self.num_vectors):
            # Generate a unique MAC using the loop index
            unique_src = f"0A:00:00:00:{i//256:02x}:{i%256:02x}"
            unique_dst = f"0B:00:00:00:{i//256:02x}:{i%256:02x}"
            pkt = self._build_packet(unique_src, unique_dst)
            # Alternate ports
            port = i % self.num_ports
            self._write_packet(port=port, delay_cycles=20, pkt=pkt)


if __name__ == "__main__":
    # Adjust parameters here
    generator = SwitchTestGenerator(num_ports=4, num_vectors=100)
    
    # Run the tests to populate the text files
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
    
    print("Done! Check the 'test_vectors' directory.")
