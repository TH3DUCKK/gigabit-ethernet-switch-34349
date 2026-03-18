library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mac_learning_unit is
  generic (
    NUM_PORTS      : integer := 4;
    BITS_PER_PORT  : integer := 8;
    DATA_BUS_WIDTH : integer := NUM_PORTS * BITS_PER_PORT;
    VALID_BITS     : integer := NUM_PORTS;
    ERROR_BITS     : integer := NUM_PORTS;
    MAC_SIZE       : integer := 48
  );
  port (
    -- Clock and reset
    clk : in std_logic;
    rst : in std_logic;
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
end entity mac_learning_unit;