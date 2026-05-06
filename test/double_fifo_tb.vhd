LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.constants.all;

entity double_fifo_tb is
end entity double_fifo_tb;

architecture sim of double_fifo_tb is

  constant CLK_PERIOD : time := 10 ns;

  -- DUT signals
  signal clk             : std_logic := '0';
  signal rst             : std_logic := '0';

  -- Write interface
  signal wr_en           : std_logic := '0';
  signal write_data      : std_logic_vector(BITS_PER_PORT-1 downto 0) := (others => '0');
  signal error_data      : std_logic := '0';

  -- Destination input
  signal dest_port       : std_logic_vector(NUM_PORTS-1 downto 0) := (others => '0');
  signal dest_port_valid : std_logic := '0';

  -- Request to send
  signal request_ack     : std_logic_vector(NUM_PORTS-1 downto 0) := (others => '0');
  signal out_data_valid  : std_logic;
  signal send_request    : std_logic_vector(NUM_PORTS-1 downto 0);
  signal packet_data     : std_logic_vector(BITS_PER_PORT-1 downto 0);

  -- Testbench organisation
  type test_state_t is (
    RESET,
    WRITING,
    READING,
    ERROR_PACKET,
    WAITING
  );

  signal test_state : test_state_t := RESET;

begin

  -- DUT Instantiation
  dut : entity work.double_fifo
    port map (
      clk             => clk,
      rst             => rst,

      wr_en           => wr_en,
      write_data      => write_data,
      error_data      => error_data,

      dest_port       => dest_port,
      dest_port_valid => dest_port_valid,

      request_ack     => request_ack,
      out_data_valid  => out_data_valid,
      send_request    => send_request,
      packet_data     => packet_data
    );

  -- Clock generation
  clk_process : process
  begin
    while true loop
      clk <= '0';
      wait for CLK_PERIOD / 2;

      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
  end process;

  -- Reset generation
  rst_process : process
  begin
    rst <= '0';
    wait for 5 * CLK_PERIOD;

    rst <= '1';
    wait;
  end process;

  -- Stimulus process
  stim_proc : process
  begin

    -- Wait until reset deasserted
    wait until rst = '1';
    wait until rising_edge(clk);

    -- Write 
    test_state <= WRITING;
    for i in 0 to 127 loop -- packet size 128
      wr_en      <= '1';
      write_data <= "01010101";
      if i = 120 then
        -- Setting destination
        dest_port       <= "0001";
        dest_port_valid <= '1';
      else
        dest_port       <= "0000";
        dest_port_valid <= '0';
      end if;
      wait until rising_edge(clk);
    end loop;

    -- Stop writing
    wr_en <= '0';
    wait until rising_edge(clk);

    -- Wait before sending acknowledge
    wait for 10 * CLK_PERIOD;

    -- Send 1 cycle acknowledge
    test_state <= READING;
    wait until rising_edge(clk);
    request_ack <= "0001";
    wait until rising_edge(clk);
    request_ack <= (others => '0');

    wait until rising_edge(clk);
    wait for 127 * CLK_PERIOD;

    -- Write error packet
    test_state <= ERROR_PACKET;
    for i in 0 to 63 loop -- packet size 64
      wr_en      <= '1';
      write_data <= "11110000";
      if i = 50 then
        -- Setting destination
        dest_port       <= "0001";
        dest_port_valid <= '1';
      else
        dest_port       <= "0000";
        dest_port_valid <= '0';
      end if;
      wait until rising_edge(clk);
    end loop;

    -- Stop writing and flag error
    wr_en <= '0';
    error_data <= '1';
    wait until rising_edge(clk);
    error_data <= '0';
    wait until rising_edge(clk);

    -- End Simulation
    wait for 20 * CLK_PERIOD;
    assert false report "Simulation finished" severity failure;

  end process;

end architecture sim;