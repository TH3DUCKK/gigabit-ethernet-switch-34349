library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

-- Description:
-- The design requires 4 of these "slices" to be instantiated.
-- Each will take input directly from the FCS/CRC module and load
-- data into a FIFO. While this is happening, it will extract
-- information used for MAC learning, and if an error is found
-- by the FCS/CRC module, the data will be marked to be discarded.

entity data_parking_slice is
  port(
    -- Clock and reset
    clk: in std_logic;
    rst: in std_logic;

    -- Data input
    input_data  : in std_logic_vector(BITS_PER_PORT - 1 downto 0);
    input_valid : in std_logic;
    input_error : in std_logic;

    -- Input from MAC
    mac_ready       : in std_logic;
    input_valid_mac : in std_logic;
    dest_port       : in std_logic_vector(NUM_PORTS - 1 downto 0);
    
    -- Outputs to MAC
    output_valid_mac : out std_logic;
    src_port         : out std_logic_vector(NUM_PORTS - 1 downto 0);
    dest_mac         : out std_logic_vector(MAC_SIZE - 1 downto 0);
    src_mac          : out std_logic_vector(MAC_SIZE - 1 downto 0);

    output_data      : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
    output_valid     : out std_logic
  );

end entity data_parking_slice;


architecture rtl of data_parking_slice is
  signal packet_length_cnt : std_logic_vector(11 downto 0); -- log2(max_packet_length)
  

begin
  process(clk, rst)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        -- Reset logic
      else
        -- Count length of packet
        

        -- Update meta data register


        -- Update MAC src and dest registers


        -- Set src port register (constant value)
      end if;
    end if;
  end process;

end architecture rtl;