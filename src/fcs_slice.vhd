library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.constants.all;

entity fcs_slice is
  port (
    -- Clock and reset
    clk : in std_logic;
    rst : in std_logic;
    -- Data inputs
    input_data  : in std_logic_vector(BITS_PER_PORT - 1 downto 0);
    input_valid : in std_logic;
    -- Data outputs
    output_data  : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
    output_valid : out std_logic;
    output_error : out std_logic
  );
end entity fcs_slice;

architecture rtl of fcs_slice is
  constant G : std_logic_vector(31 downto 0) := "00000100110000010001110110110111"; -- generator polynomial
  signal R   : std_logic_vector(31 downto 0) := x"00000000"; -- remainder polynomial
  signal M   : std_logic_vector(7 downto 0)  := x"00"; -- input message
  signal start_cnt : std_logic_vector(4 downto 0)  := "00000"; -- counter to know how many bits to invert at the start
  signal preamble_cnt : std_logic_vector(2 downto 0)  := "000"; -- counter to track how many bytes to ignore at the start
  --signal preamble_reading : std_logic := '0'; -- signal indicating the preamble is being read
  signal frame_starting : std_logic := '0'; -- signal indicating a packet is starting
  signal prev_valid_in : std_logic := '0'; -- signal storing previous valid input value
  signal state : std_logic_vector(1 downto 0); -- state register, read states below
begin
  process(clk, rst)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        R <= x"00000000";
        M <= x"00";
        start_cnt <= "00000";
        preamble_cnt <= "000";
        frame_starting <= '0';
        prev_valid_in <= '0';
      else
        -- setting io
        output_data <= input_data;
        output_valid <= input_valid;
      
        -- saving previous valid value
        prev_valid_in <= input_valid;

        -- default assignment (gets overwritten by the FSM below)
        output_error <= '0';

        -- FSM states
        -- 00 - IDLE: No data is being provided at the input
        -- 01 - PREAMBLE: The preamble is being read
        -- 10 - PACKET_START: The first 4 bytes are inverted in the remainder polynomial
        -- 11 - REST_OF_PACKET All other bytes are read normally into the remainder polynomial
        case state is
          -- IDLE
          when "00" =>
            if prev_valid_in = '0' and input_valid = '1' and preamble_cnt = "000" then
              preamble_cnt <= "001";
              state <= "01";
            else
              state <= "00";
            end if;
          
          -- PREAMBLE
          when "01" =>
            if preamble_cnt <= "111" then
              M <= x"00";
              preamble_cnt <= "000";
              start_cnt <= "00001";
              R <= x"00000000";
              state <= "10";
            else
              M <= not input_data;
              preamble_cnt <= preamble_cnt + '1';
              start_cnt <= "00000";
              state <= "01";
            end if;
        
          -- PACKET_START
          when "10" =>
            if start_cnt = "11111" then
              M <= input_data;
              start_cnt <= "00000";
              state <= "11";
            else
              M <= not input_data;
              start_cnt <= start_cnt + '1';
              state <= "10";
            end if;
        
          -- REST_OF_PACKET
          when "11" =>
            if prev_valid_in = '1' and input_valid = '0' then
              M <= x"00";
              if R /= x"FFFFFFFF" then
                output_error <= '1';
              else
                output_error <= '0';
              end if;
            else
              M <= input_data;
              state <= "00";
            end if;

            when others =>
              state <= "00";
        end case;

        -- R signal definitions based on matlab script
        R(0)  <= R(24) xor R(30) xor M(0);
        R(1)  <= R(24) xor R(25) xor R(30) xor R(31) xor M(1);
        R(2)  <= R(24) xor R(25) xor R(26) xor R(30) xor R(31) xor M(2);
        R(3)  <= R(25) xor R(26) xor R(27) xor R(31) xor M(3);
        R(4)  <= R(24) xor R(26) xor R(27) xor R(28) xor R(30) xor M(4);
        R(5)  <= R(24) xor R(25) xor R(27) xor R(28) xor R(29) xor R(30) xor R(31) xor M(5);
        R(6)  <= R(25) xor R(26) xor R(28) xor R(29) xor R(30) xor R(31) xor M(6);
        R(7)  <= R(24) xor R(26) xor R(27) xor R(29) xor R(31) xor M(7);
        R(8)  <= R(0)  xor R(24) xor R(25) xor R(27) xor R(28);
        R(9)  <= R(1)  xor R(25) xor R(26) xor R(28) xor R(29);
        R(10) <= R(2)  xor R(24) xor R(26) xor R(27) xor R(29);
        R(11) <= R(3)  xor R(24) xor R(25) xor R(27) xor R(28);
        R(12) <= R(4)  xor R(24) xor R(25) xor R(26) xor R(28) xor R(29) xor R(30);
        R(13) <= R(5)  xor R(25) xor R(26) xor R(27) xor R(29) xor R(30) xor R(31);
        R(14) <= R(6)  xor R(26) xor R(27) xor R(28) xor R(30) xor R(31);
        R(15) <= R(7)  xor R(27) xor R(28) xor R(29) xor R(31);
        R(16) <= R(8)  xor R(24) xor R(28) xor R(29);
        R(17) <= R(9)  xor R(25) xor R(29) xor R(30);
        R(18) <= R(10) xor R(26) xor R(30) xor R(31);
        R(19) <= R(11) xor R(27) xor R(31);
        R(20) <= R(12) xor R(28);
        R(21) <= R(13) xor R(29);
        R(22) <= R(14) xor R(24);
        R(23) <= R(15) xor R(24) xor R(25) xor R(30);
        R(24) <= R(16) xor R(25) xor R(26) xor R(31);
        R(25) <= R(17) xor R(26) xor R(27);
        R(26) <= R(18) xor R(24) xor R(27) xor R(28) xor R(30);
        R(27) <= R(19) xor R(25) xor R(28) xor R(29) xor R(31);
        R(28) <= R(20) xor R(26) xor R(29) xor R(30);
        R(29) <= R(21) xor R(27) xor R(30) xor R(31);
        R(30) <= R(22) xor R(28) xor R(31);
        R(31) <= R(23) xor R(29);
      end if;
    end if;

  end process;
end architecture rtl;
