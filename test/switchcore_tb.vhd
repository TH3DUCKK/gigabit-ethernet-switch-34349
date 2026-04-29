library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

entity switchcore_tb is
end entity switchcore_tb;

architecture tb of switchcore_tb is

  -- Component declaration
  component switchcore is
    port (
      -- Clock and reset
      clk : in std_logic;
      rst : in std_logic;

      -- Activity indicators
      link_sync : in std_logic_vector(3 downto 0); -- High indicates a peer connection at the physical layer.

      -- Four GMII interfaces
      tx_data : out std_logic_vector(31 downto 0); -- (7 downto 0)=TXD0...(31 downto 24=TXD3)
      tx_ctrl : out std_logic_vector(3 downto 0); -- (0)=TXC0...(3=TXC3)
      rx_data : in std_logic_vector(31 downto 0); -- (7 downto 0)=RXD0...(31 downto 24=RXD3)
      rx_ctrl : in std_logic_vector(3 downto 0)  -- (0)=RXC0...(3=RXC3)
    );
  end component switchcore;

  type test_state_type is (INIT, SEND_PACKET, RECEIVE_PACKET, END_SIM);
  signal test_state : test_state_type := INIT;

  -- Signal declarations
  signal clk       : std_logic := '0';
  signal rst       : std_logic := '0';
  signal link_sync : std_logic_vector(3 downto 0) := (others => '0');
  signal port0_tx : std_logic_vector(7 downto 0);
  signal port1_tx : std_logic_vector(7 downto 0);
  signal port2_tx : std_logic_vector(7 downto 0);
  signal port3_tx : std_logic_vector(7 downto 0);
  signal tx_ctrl : std_logic_vector(3 downto 0);
  signal port0_rx : std_logic_vector(7 downto 0);
  signal port1_rx : std_logic_vector(7 downto 0);
  signal port2_rx : std_logic_vector(7 downto 0);
  signal port3_rx : std_logic_vector(7 downto 0);
  signal rx_ctrl : std_logic_vector(3 downto 0);

  constant CLK_PERIOD : time := 10 ns;

begin

  dut : switchcore
    port map (
      clk => clk,
      rst => rst,
      link_sync => link_sync,
      tx_data => port0_tx & port1_tx & port2_tx & port3_tx,
      tx_ctrl => tx_ctrl,
      rx_data => port0_rx & port1_rx & port2_rx & port3_rx,
      rx_ctrl => rx_ctrl
    );

  -- Clock generation
  clk <= not clk after CLK_PERIOD / 2;

  test_process : process
  begin
    -- Initial values
    link_sync <= "0000";
    port0_rx <= (others => '0');
    port1_rx <= (others => '0');
    port2_rx <= (others => '0');
    port3_rx <= (others => '0');
    rx_ctrl <= (others => '0');

    -- Reset
    rst <= '1';
    wait for CLK_PERIOD * 2;
    rst <= '0';
    wait for CLK_PERIOD;
    
    -- Tests:
    -- Standard packet transmission from one port to another
    -- Check for correct handling of back-to-back packets
    -- Check if mac learning is working with packets (i.e. stopping with broadcasting)
    -- Check for correct handling of packets with errors (both pure errors, then also whit good packets inbetween)
    -- Check for packets coming in at the same time on multiple ports
    -- Check for congestion i.e. overloading one port
    -- Check for heavy loads, lots of packets from lots of ports.
    -- Check for handling of fifo filling up because of big packets
    -- Check for primarily big packets
    -- Check for primarily small packets
    -- Check for edge case of having only unique mac addresses in packets.


  end process;

end architecture;