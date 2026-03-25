library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

entity mac_learning_unit_tb is
end entity mac_learning_unit_tb;

architecture tb of mac_learning_unit_tb is
  -- Component declaration
  component mac_learning_unit is
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
  end component mac_learning_unit;

  type test_state_type is (INIT, TEST1, TEST2, TEST3, END_SIM);
  signal test_state : test_state_type := INIT;

  -- Signal declarations
  signal clk        : std_logic := '0';
  signal rst        : std_logic := '0';
  signal source_mac : std_logic_vector(47 downto 0);
  signal src_port   : std_logic_vector(3 downto 0);
  signal valid      : std_logic := '0';
  signal dest_mac   : std_logic_vector(47 downto 0);
  signal dest_port  : std_logic_vector(3 downto 0);
  signal ready      : std_logic;

  constant CLK_PERIOD : time := 10 ns;

begin
  -- Instantiate the unit under test
  dut : mac_learning_unit
  port map (
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
    test_state  <= INIT;

    -- Reset
    rst <= '1';
    wait for CLK_PERIOD * 2;
    rst <= '0';
    wait for CLK_PERIOD;

    -- Test case 1: Learn a MAC address
    test_state  <= TEST1;
    source_mac <= x"001122334455";
    src_port   <= "0001";
    valid      <= '1';
    report "wait for ready 1" severity note;
    wait until ready = '1';
    valid <= '0'; -- Deassert valid after the first transaction
    wait for CLK_PERIOD;

    valid <= '1';
    dest_mac <= x"001122334455";
    report "wait for ready 2" severity note;
    wait until ready = '1'; 
    assert (dest_port = "0001")
    report "Test case 1: Look up learned address - Expected dest_port = 0001, got " & integer'image(to_integer(unsigned(dest_port)))
      severity FAILURE;
    valid <= '0';
    wait for CLK_PERIOD * 2;

    -- Test case 2: Learn another MAC address
    test_state  <= TEST2;
    source_mac <= x"aabbccddeeff";
    src_port   <= "0010";
    valid      <= '1';
    wait until ready = '1';
    valid <= '0'; -- Deassert valid after the first transaction
    wait for CLK_PERIOD;

    valid <= '1';
    dest_mac <= x"aabbccddeeff";
    wait until ready = '1'; 
    assert (dest_port = "0010")
    report "Test case 2: Look up learned address - Expected dest_port = 0010, got " & integer'image(to_integer(unsigned(dest_port)))
      severity FAILURE;
    valid <= '0';
    wait for CLK_PERIOD * 2;

    -- Test case 3: Look up an unknown address
    test_state  <= TEST3;
    valid <= '1';
    dest_mac <= x"112233445566";
    src_port <= "0001"; -- Source port should not be flooded back
    wait until ready = '1';
    assert (dest_port = "1110")
    report "Test case 3: Look up unknown address - Expected dest_port = 1110, got " & integer'image(to_integer(unsigned(dest_port)))
      severity FAILURE;
    wait for CLK_PERIOD * 5;
    assert (dest_port = "1110")
    report "Test case 3: Look up unknown address and holding until ready low - Expected dest_port = 1110, got " & integer'image(to_integer(unsigned(dest_port)))
      severity FAILURE; 
    
    test_state <= END_SIM;
    assert false
      report "End of simulation"
      severity FAILURE;
    wait;
    
  end process test_process;

end architecture tb;