library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

entity mac_learning_top_tb is
end entity mac_learning_top_tb;

architecture tb of mac_learning_top_tb is
  -- Component declaration
  component mac_learning_top is
    port (
      -- Clock and reset
      clk : in std_logic;
      rst : in std_logic;
      -- Mac inputs
      valid      : in std_logic;
      src_port   : in std_logic_vector(NUM_PORTS - 1 downto 0); -- One bit per port
      source_mac : in std_logic_vector(MAC_SIZE - 1 downto 0);
      dest_mac   : in std_logic_vector(MAC_SIZE - 1 downto 0);
      -- Mac outputs
      ready     : out std_logic;
      dest_port : out std_logic_vector(NUM_PORTS - 1 downto 0) -- One bit per port
    );
  end component mac_learning_top;

  type test_state_type is (INIT, 
                          TEST1_LEARN, TEST1_LOOKUP, 
                          TEST2_LEARN, TEST2_LOOKUP, 
                          TEST3_LOOKUP, 
                          TEST4_AGE, 
                          TEST5_AGEOUT_START, TEST5_AGEOUT_WAIT, TEST5_AGEOUT_END_WRITE, TEST5_AGEOUT_END_CHECK, 
                          END_SIM);
  signal test_state : test_state_type := INIT;

  -- Signal declarations
  signal clk        : std_logic := '0';
  signal rst        : std_logic := '0';
  signal source_mac : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal src_port   : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal valid      : std_logic := '0';
  signal dest_mac   : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal dest_port  : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal ready      : std_logic;

  constant CLK_PERIOD : time := 10 ns;

begin
  -- Instantiate the unit under test
  dut : mac_learning_top
  port map
  (
    clk        => clk,
    rst        => rst,
    valid      => valid,
    src_port   => src_port,
    source_mac => source_mac,
    dest_mac   => dest_mac,
    ready      => ready,
    dest_port  => dest_port
  );

  -- Clock generation
  clk <= not clk after CLK_PERIOD / 2;

  -- Test stimulus
  test_process : process
  begin

    -- Initial values
    source_mac <= (others => '0');
    dest_mac   <= (others => '0');
    src_port   <= (others => '0');
    valid      <= '0';
    test_state <= INIT;

    -- Reset
    rst <= '0';
    wait for CLK_PERIOD * 2;
    rst <= '1';
    wait for CLK_PERIOD;

    -- Test case 1: Learn a MAC address
    test_state <= TEST1_LEARN;
    source_mac <= x"001122334455";
    src_port   <= "0001";
    valid      <= '1';
    wait until ready = '1';
    valid <= '0'; -- Deassert valid after the first transaction
    wait for CLK_PERIOD * 2;

    test_state <= TEST1_LOOKUP;
    valid      <= '1';
    dest_mac   <= x"001122334455";
    wait until ready = '1';
    assert (dest_port = "0001")
    report "Test case 1: Look up learned address - Expected dest_port = 0001, got " & to_string(dest_port)
      severity FAILURE;
    valid <= '0';
    wait for CLK_PERIOD * 2;

    -- Test case 2: Learn another MAC address
    test_state <= TEST2_LEARN;
    source_mac <= x"aabbccddeeff";
    src_port   <= "0010";
    valid      <= '1';
    wait until ready = '1';
    valid <= '0'; -- Deassert valid after the first transaction
    wait for CLK_PERIOD;

    test_state <= TEST2_LOOKUP;
    valid      <= '1';
    dest_mac   <= x"aabbccddeeff";
    wait until ready = '1';
    assert (dest_port = "0010")
    report "Test case 2: Look up learned address - Expected dest_port = 0010, got " & to_string(dest_port)
      severity FAILURE;
    valid <= '0';
    wait for CLK_PERIOD * 2;

    -- Test case 3: Look up an unknown address
    test_state <= TEST3_LOOKUP;
    valid      <= '1';
    dest_mac   <= x"112233445566";
    src_port   <= "0001"; -- Source port should not be flooded back
    wait until ready = '1';
    assert (dest_port = "1110")
    report "Test case 3: Look up unknown address - Expected dest_port = 1110, got " & to_string(dest_port)
      severity FAILURE;

    wait for CLK_PERIOD * 5;
    assert (dest_port = "1110")
    report "Test case 3: Look up unknown address and holding until ready low - Expected dest_port = 1110, got " & to_string(dest_port)
      severity FAILURE;

    valid <= '0';
    wait for CLK_PERIOD * 2;


    -- Test case 4: Check if age increases (need to inspect waveforms for this one)
    test_state <= TEST4_AGE;
    valid      <= '1';
    dest_mac   <= x"001122334455";
    wait until ready = '1';
    valid <= '0';
    wait for CLK_PERIOD * 2 * 2**MAC_RAM_SIZE_BITS * 4 * 2; -- Wait for enough time to ensure that the age of the first entry has increased at least once
    valid      <= '1';
    dest_mac   <= x"001122334455";
    wait until ready = '1';
    assert (dest_port = "0001")
    report "Test case 4: Check if age increases - Expected dest_port = 0001, got " & to_string(dest_port)
      severity FAILURE;
    valid <= '0';
    wait for CLK_PERIOD * 2;

    -- Test case 5: Age out the first learned address
    test_state <= TEST5_AGEOUT_START;

    -- Try and introduce something to the MAC learning unit to see if it gets written
    source_mac <= x"111122334455";
    src_port   <= "0100";
    valid      <= '1';
    wait until ready = '1';
    valid <= '0'; -- Deassert valid after the transaction
    wait for CLK_PERIOD * 2;

    -- Wait and then check if it was successfully written to.
    valid      <= '1';
    dest_mac   <= x"111122334455";
    wait until ready = '1';
    assert (dest_port = "1011")
    report "Test case 5: Check if address is learned should not be - Expected dest_port = 1011, got " & to_string(dest_port)
      severity FAILURE;
    valid <= '0';
    wait for CLK_PERIOD * 2;

    -- Check if the first entry actually exist before waiting for it to age out
    valid      <= '1';
    dest_mac   <= x"001122334455";
    wait until ready = '1';
    assert (dest_port = "0001")
    report "Test case 5: Check if first entry exists - Expected dest_port = 0001, got " & to_string(dest_port)
      severity FAILURE;
    valid <= '0';
    wait for CLK_PERIOD * 2;
    test_state <= TEST5_AGEOUT_WAIT;
    -- Then wait for max age time
    source_mac <= x"DEADDEADBEEF"; -- Keep the port different from the one we want to age out, since mac clearing does not write to the current source mac.

    -- Should only be run with testing values for MAC_AGE_MAX and MAC_AGE_CLOCK_DIVISION, otherwise the wait time will be VERY VERY long
    wait for CLK_PERIOD * 2 * (MAC_AGE_CLOCK_DIVISION * MAC_AGE_MAX * 3 * 2**MAC_RAM_SIZE_BITS + 1); -- Wait for the maximum age time to ensure the first entry ages out
    test_state <= TEST5_AGEOUT_END_WRITE;
    -- Write again
    source_mac <= x"111122334455";
    src_port   <= "0100";
    valid      <= '1';
    wait until ready = '1';
    valid <= '0'; -- Deassert valid after the transaction
    wait for CLK_PERIOD * 2;
    -- Check again 
    test_state <= TEST5_AGEOUT_END_CHECK;
    valid      <= '1';
    dest_mac   <= x"111122334455";
    wait until ready = '1';
    assert (dest_port = "0100")
      report "Test case 5: Check if address was overwritten - Expected dest_port = 0100, got " & to_string(dest_port)
      severity FAILURE;
    
    test_state <= END_SIM;
    wait for CLK_PERIOD * 2;
    
    assert false
    report "End of simulation"
      severity FAILURE;
    wait;

  end process test_process;

end architecture tb;