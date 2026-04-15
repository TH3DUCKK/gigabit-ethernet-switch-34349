library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

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
    data_in    : in std_logic_vector (MAC_WORD_SIZE - 1 downto 0);
    source_mac : in std_logic_vector(MAC_SIZE - 1 downto 0);

    -- Output signals
    address  : out std_logic_vector (MAC_RAM_SIZE_BITS - 1 downto 0);
    wren     : out std_logic;
    data_out : out std_logic_vector (MAC_WORD_SIZE - 1 downto 0)
  );
end entity mac_clearing_unit;

architecture rtl of mac_clearing_unit is
  type state_type is (IDLE, READ_AGE, WRITE_AGE);

  signal state, state_next : state_type;
  signal addr, addr_next   : unsigned(MAC_RAM_SIZE_BITS - 1 downto 0);

begin
  process (clk, rst)
  begin
    if rst = '1' then
      state <= IDLE;
      addr  <= (others => '0');
    elsif rising_edge(clk) then
      state <= state_next;
      addr  <= addr_next;
    end if;
  end process;

  process (state, addr, data_in)
  begin
    state_next <= state;
    addr_next  <= addr;
    address    <= std_logic_vector(addr);
    wren       <= '0';
    data_out   <= (others => '0');

    case state is
      when IDLE =>
        state_next <= READ_AGE;

      when READ_AGE =>
        state_next <= WRITE_AGE;

      when WRITE_AGE =>
        data_out <= data_in + 1;
        if (data_in = std_logic_vector(to_unsigned(MAC_AGE_MAX, data_in'length))) and
          std_logic_vector(addr) /= source_mac(MAC_RAM_SIZE_BITS - 1 downto 0) then

          wren       <= '1';
          addr_next  <= addr + 1;
          state_next <= READ_AGE;
        else
          wren       <= '0';
          addr_next  <= addr;
          state_next <= WRITE_AGE;
        end if;
    end case;
  end process;

end architecture rtl;