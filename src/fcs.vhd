library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fcs is
  generic (
    NUM_PORTS      : integer := 4;
    BITS_PER_PORT  : integer := 8;
    DATA_BUS_WIDTH : integer := NUM_PORTS * BITS_PER_PORT;
    VALID_BITS     : integer := NUM_PORTS;
    ERROR_BITS     : integer := NUM_PORTS
  );
  port (
    -- Clock and reset
    clk : in std_logic;
    rst : in std_logic;
    -- Data inputs
    input_data  : in std_logic_vector(DATA_BUS_WIDTH - 1 downto 0);
    input_valid : in std_logic_vector(VALID_BITS - 1 downto 0);
    -- Data outputs
    output_data  : out std_logic_vector(DATA_BUS_WIDTH - 1 downto 0);
    output_valid : out std_logic_vector(VALID_BITS - 1 downto 0);
    output_error : out std_logic_vector(ERROR_BITS - 1 downto 0)
  );
end entity fcs;
