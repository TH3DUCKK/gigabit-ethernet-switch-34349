library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

entity fcs is
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
