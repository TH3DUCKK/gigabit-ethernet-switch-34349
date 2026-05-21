library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.constants.all;

entity switchcore_unicast_tb is
end entity;

architecture tb of switchcore_unicast_tb is

  -- Component declaration
  component switchcore is
    port (
      -- Clock and reset
      clk   : in std_logic;
      reset : in std_logic;

      -- Activity indicators
      link_sync : in std_logic_vector(3 downto 0); -- High indicates a peer connection at the physical layer.

      -- Four GMII interfaces
      tx_data : out std_logic_vector(31 downto 0); -- (7 downto 0)=TXD0...(31 downto 24=TXD3)
      tx_ctrl : out std_logic_vector(3 downto 0); -- (0)=TXC0...(3=TXC3)
      rx_data : in std_logic_vector(31 downto 0); -- (7 downto 0)=RXD0...(31 downto 24=RXD3)
      rx_ctrl : in std_logic_vector(3 downto 0) -- (0)=RXC0...(3=RXC3)
    );
  end component switchcore;

  -- Signal declarations
  signal clk       : std_logic                    := '0';
  signal rst       : std_logic                    := '0';
  signal link_sync : std_logic_vector(3 downto 0) := (others => '0');
  signal tx_data   : std_logic_vector(31 downto 0);
  signal tx_ctrl   : std_logic_vector(3 downto 0);
  signal port0_rx  : std_logic_vector(7 downto 0);
  signal port1_rx  : std_logic_vector(7 downto 0);
  signal port2_rx  : std_logic_vector(7 downto 0);
  signal port3_rx  : std_logic_vector(7 downto 0);
  signal rx_ctrl   : std_logic_vector(3 downto 0);

  -- Clock counter
  signal clock_counter : integer := 0;

  -- Test ip-packet





  constant DATA            : std_logic_vector(575 downto 0)   := x"55555555555555d500000000000200000000000108004500002e000100004011f96ac0a80001c0a8000204d2162e001a6366aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa58d56429";
  constant DATA_OPPOSITE_DIR : std_logic_vector(575 downto 0) := x"55555555555555d500000000000100000000000208004500002e000100004011f96ac0a80001c0a8000204d2162e001a6366aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabd88916";
  constant CLK_PERIOD      : time                           := 10 ns;

begin

  DUT : entity work.switchcore
    port map
    (
      clk       => clk,
      reset     => rst,
      link_sync => link_sync,
      -- Note on concatenation: port0_tx & port1_tx means port0 is in bits 31 downto 24
      tx_data => tx_data,
      tx_ctrl => tx_ctrl,
      rx_data => port3_rx & port2_rx & port1_rx & port0_rx,
      rx_ctrl => rx_ctrl
    );

  -- Clock generation
  clk <= not clk after CLK_PERIOD / 2;

  test_process : process
  begin

    -- Default values
    link_sync <= (others => '0');
    port0_rx <= (others => '0');
    port1_rx <= (others => '0');
    port2_rx <= (others => '0');
    port3_rx <= (others => '0');

    rst <= '0';
    wait for CLK_PERIOD * 2;
    rst <= '1';
    wait for CLK_PERIOD;
    rx_ctrl <= "0000";
    wait for CLK_PERIOD;
    for i in (((DATA'high + 1) / 8) - 1) downto DATA'low loop
      rx_ctrl <= "0001";
      port0_rx<= DATA((i*8)+7 downto (i)*8);
      wait for CLK_PERIOD;
    end loop;
    rx_ctrl <= "0000";
    wait for CLK_PERIOD * 12;
    wait for CLK_PERIOD * 100;
    for i in (((DATA'high + 1) / 8) - 1) downto DATA'low loop
      rx_ctrl <= "0010";
      port1_rx<= DATA_OPPOSITE_DIR((i*8)+7 downto (i)*8);
      wait for CLK_PERIOD;
    end loop;
    rx_ctrl <= "0000";
    wait for CLK_PERIOD * 200;

    assert FALSE
      report "END of simulation"
      severity FAILURE;
    wait;
    
  end process;

  clock_process : process (clk)
  begin
    if rising_edge(clk) then
      clock_counter <= clock_counter + 1;
    end if;
  end process;

end architecture;