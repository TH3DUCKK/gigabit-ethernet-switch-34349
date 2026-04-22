library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

-- Description:
-- Top module for the data parking module that instantiates 4 sub-modules
-- that each "park" data from the FCS/CRC module.
-- This module functions as an arbiter between the four sub-modules
-- and the MAC learning unit. The arbitration will be handled by a simple
-- round-Robin "algorithm".

entity data_parking is
  port (
    -- Clock and reset
    clk : in std_logic;
    rst : in std_logic;
    -- Data inputs
    input_data  : in std_logic_vector(DATA_BUS_WIDTH - 1 downto 0);
    input_valid : in std_logic_vector(VALID_BITS - 1 downto 0);
    input_error : in std_logic_vector(ERROR_BITS - 1 downto 0);
    -- Data outputs
    output_data  : out std_logic_vector(DATA_BUS_WIDTH - 1 downto 0);
    output_valid : out std_logic_vector(VALID_BITS - 1 downto 0);
    -- Mac inputs
    ready           : in std_logic;
    input_valid_mac : in std_logic;
    dest_port       : in std_logic_vector(NUM_PORTS - 1 downto 0); -- One bit per port
    -- Mac outputs
    output_valid_mac : out std_logic;
    dest_mac         : out std_logic_vector(MAC_SIZE - 1 downto 0);
    source_mac       : out std_logic_vector(MAC_SIZE - 1 downto 0);
    src_port         : out std_logic_vector(NUM_PORTS - 1 downto 0) -- One bit per port
  );
end entity data_parking;

architecture rtl of data_parking is



begin
  process (clk, rst)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        -- Reset logic
        output_data <= (others => '0');
      else
        output_data <= input_data;
      end if;
    end if;
  end process;
end architecture rtl;