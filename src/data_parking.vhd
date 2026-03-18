library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity data_parking is
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
      if rst = '1' then
        -- Reset logic
        output_data <= (others => '0');
      else
        output_data <= input_data;
      end if;
    end if;
  end process;
end architecture rtl;