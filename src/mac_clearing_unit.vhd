library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use IEEE.math_real.LOG2;
use IEEE.math_real.CEIL;

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
  type state_type is (IDLE, READ_AGE, WAIT_AGE, WRITE_AGE);

  signal state, state_next : state_type;
  signal addr, addr_next   : unsigned(MAC_RAM_SIZE_BITS - 1 downto 0);
  signal timer, timer_next : unsigned(integer(ceil(log2(real(MAC_AGE_CLOCK_DIVISION)))) downto 0); -- Timer to divide the clock (HOLY ONELINER)

begin
  process (clk, rst)
  begin
    if rst = '0' then
      state <= IDLE;
      addr  <= (others => '0');
      timer <= (others => '0');
    elsif rising_edge(clk) then
      state <= state_next;
      addr  <= addr_next;
      timer <= timer_next;
    end if;
  end process;

  process (state, addr, data_in, timer)
  begin
    state_next <= state;
    addr_next  <= addr;
    timer_next <= timer;
    address    <= std_logic_vector(addr);
    wren       <= '0';
    data_out   <= (others => '0');

    case state is
      when IDLE =>
        if timer >= MAC_AGE_CLOCK_DIVISION then
          state_next <= READ_AGE;
          timer_next <= (others => '0');
        else
          timer_next <= timer + 1;
          state_next <= IDLE;
        end if;

      when READ_AGE =>
        state_next <= WAIT_AGE;
      when WAIT_AGE =>
        state_next <= WRITE_AGE;
      when WRITE_AGE =>
        timer_next <= (others => '0');
        data_out   <= data_in + 1;
        addr_next  <= addr + 1;
        state_next <= IDLE;
        -- Check if the age has reached the maximum age and check if the MAC learning unit is not working on the same entry
        if (data_in(MAC_WORD_SIZE - MAC_SIZE - NUM_PORTS - 1 downto 0) /= std_logic_vector(to_unsigned(MAC_AGE_MAX, integer(ceil(log2(real(MAC_AGE_MAX))))))) and 
            std_logic_vector(addr) /= source_mac(MAC_RAM_SIZE_BITS - 1 downto 0) then
          wren <= '1';
        else
          wren <= '0';
        end if;
    end case;
  end process;

end architecture rtl;