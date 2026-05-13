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

architecture rtl of fcs is
  component fcs_slice is
    port (
      clk          : in std_logic;
      rst          : in std_logic;
      input_data   : in std_logic_vector(BITS_PER_PORT - 1 downto 0);
      input_valid  : in std_logic;
      output_data  : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
      output_valid : out std_logic;
      output_error : out std_logic
    );
  end component;

begin
  u_fcs_slice_0 : fcs_slice
  port map (
    clk          => clk,
    rst          => rst,
    input_data   => input_data((BITS_PER_PORT * 1) - 1 downto BITS_PER_PORT * 0),
    input_valid  => input_valid(0),
    output_data  => output_data((BITS_PER_PORT * 1) - 1 downto BITS_PER_PORT * 0),
    output_valid => output_valid(0),
    output_error => output_error(0)
  );

  u_fcs_slice_1 : fcs_slice
  port map (
    clk          => clk,
    rst          => rst,
    input_data   => input_data((BITS_PER_PORT * 2) - 1 downto BITS_PER_PORT * 1),
    input_valid  => input_valid(1),
    output_data  => output_data((BITS_PER_PORT * 2) - 1 downto BITS_PER_PORT * 1),
    output_valid => output_valid(1),
    output_error => output_error(1)
  );

  u_fcs_slice_2 : fcs_slice
  port map (
    clk          => clk,
    rst          => rst,
    input_data   => input_data((BITS_PER_PORT * 3) - 1 downto BITS_PER_PORT * 2),
    input_valid  => input_valid(2),
    output_data  => output_data((BITS_PER_PORT * 3) - 1 downto BITS_PER_PORT * 2),
    output_valid => output_valid(2),
    output_error => output_error(2)
  );

  u_fcs_slice_3 : fcs_slice
  port map (
    clk          => clk,
    rst          => rst,
    input_data   => input_data((BITS_PER_PORT * 4) - 1 downto BITS_PER_PORT * 3),
    input_valid  => input_valid(3),
    output_data  => output_data((BITS_PER_PORT * 4) - 1 downto BITS_PER_PORT * 3),
    output_valid => output_valid(3),
    output_error => output_error(3)
  );

end architecture rtl;
