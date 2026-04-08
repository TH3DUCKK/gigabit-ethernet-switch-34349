library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

-- Description:
-- This module implements the MAC clearing unit, responsible for clearing outdated or invalid MAC entries from the MAC address table. 
-- It reads the MAC_RAM and increments a counter for each entry. If an entry exceeds a certain age threshold, the learning unit will then be allowed to overwrite it.


entity mac_clearing_unit is
  port (
    -- Clock and reset
    clk : in std_logic;
    rst : in std_logic;

    -- Input signals
    data_in : in std_logic_vector (63 downto 0);

    -- Output signals
    address : out std_logic_vector (12 downto 0);
    wren : out std_logic;
    data_out : out std_logic_vector (63 downto 0)
    );
end entity mac_clearing_unit;

architecture rtl of mac_clearing_unit is

  begin

    process(clk,rst)
    begin
      -- Default values
      address <= (others => '0');
      wren <= '0';
      data_out <= (others => '0');
    end process;

end architecture rtl;