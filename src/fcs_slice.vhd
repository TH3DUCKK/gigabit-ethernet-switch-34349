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
  -- Polynomials and "input message"
  constant G : std_logic_vector(31 downto 0) := "00000100110000010001110110110111"; -- generator polynomial
  signal R   : std_logic_vector(31 downto 0) := x"00000000"; -- remainder polynomial
  signal M   : std_logic_vector(7 downto 0)  := x"00"; -- input message

  -- Counters
  signal start_cnt : std_logic_vector(1 downto 0)  := "00"; -- counter to know how many bits to invert at the start
  signal preamble_cnt : std_logic_vector(2 downto 0)  := "000"; -- counter to track how many bytes to ignore at the start

  -- Registers for input data
  signal data_in : std_logic_vector(7 downto 0) := "00000000";
  signal valid_in : std_logic := '0'; -- signal storing valid input value
  signal prev_valid_in : std_logic := '0'; -- signal storing previous valid input value

  -- FSM related
  type state_t is (IDLE, PREAMBLE, PACKET_START, REST_OF_PACKET, EVAL_ERROR);
  signal state : state_t;

begin
  process(clk, rst)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        R <= x"00000000";
        M <= x"00";
        start_cnt <= "00";
        preamble_cnt <= "000";
        data_in <= "00000000";
        valid_in <= '0';
        prev_valid_in <= '0';
        state <= IDLE;
      else
        -- putting inputs into registers
        data_in <= input_data;
        valid_in <= input_valid;
        prev_valid_in <= valid_in;
        
        -- setting outputs
        output_data <= data_in;
        output_valid <= valid_in;

        -- default assignment (gets overwritten by the FSM below)
        output_error <= '0';

        -- FSM states
        -- IDLE: No data is being provided at the input
        -- PREAMBLE: The preamble is being read
        -- PACKET_START: The first 4 bytes are inverted in the remainder polynomial
        -- REST_OF_PACKET: All other bytes are read normally into the remainder polynomial
        -- EVAL_ERROR: Evaluates if an error has occured
        case state is
          when IDLE =>
            if prev_valid_in = '0' and valid_in = '1' and preamble_cnt = "000" then
              state <= PREAMBLE;
            else
              state <= IDLE;
            end if;
          
          when PREAMBLE =>
            if preamble_cnt = "111" then
              M <= not data_in;
              preamble_cnt <= "000";
              start_cnt <= "00";
              R <= x"00000000";
              state <= PACKET_START;
            else
              M <= x"00";
              preamble_cnt <= preamble_cnt + '1';
              state <= PREAMBLE;
            end if;
          
          when PACKET_START =>
            if start_cnt = "11" then
              M <= data_in;
              start_cnt <= "00";
              state <= REST_OF_PACKET;
            else
              M <= not data_in;
              start_cnt <= start_cnt + '1';
              state <= PACKET_START;
            end if;
          
          when REST_OF_PACKET =>
            if prev_valid_in = '1' and valid_in = '0' then
              M <= x"00";
              state <= EVAL_ERROR;
            else
              M <= data_in;
              state <= REST_OF_PACKET;
            end if;

          when EVAL_ERROR =>
            state <= IDLE;
            if R /= x"FFFFFFFF" then
              output_error <= '1';
            else
              output_error <= '0';
            end if;

          
          when others =>
            state <= IDLE;
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
