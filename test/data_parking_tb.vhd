library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

entity tb_data_parking is
end entity;

architecture sim of tb_data_parking is

  --------------------------------------------------------------------------
  -- Constants
  --------------------------------------------------------------------------
  constant CLK_PERIOD      : time := 10 ns;

  --------------------------------------------------------------------------
  -- DUT Signals
  --------------------------------------------------------------------------

  -- Clock / reset
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  -- Data inputs
  signal input_data  : std_logic_vector(DATA_BUS_WIDTH - 1 downto 0) := (others => '0');
  signal input_valid : std_logic_vector(VALID_BITS - 1 downto 0) := (others => '0');
  signal input_error : std_logic_vector(ERROR_BITS - 1 downto 0) := (others => '0');

  -- MAC inputs
  signal ready     : std_logic := '0';
  signal dest_port : std_logic_vector(NUM_PORTS - 1 downto 0) := (others => '0');

  -- MAC outputs
  signal output_valid_mac : std_logic;
  signal dest_mac         : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal source_mac       : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal src_port         : std_logic_vector(NUM_PORTS - 1 downto 0);

  -- Crossbar inputs
  signal p0_ack : std_logic_vector(NUM_PORTS - 1 downto 0) := (others => '0');
  signal p1_ack : std_logic_vector(NUM_PORTS - 1 downto 0) := (others => '0');
  signal p2_ack : std_logic_vector(NUM_PORTS - 1 downto 0) := (others => '0');
  signal p3_ack : std_logic_vector(NUM_PORTS - 1 downto 0) := (others => '0');

  -- Crossbar outputs
  signal p0_data          : std_logic_vector(BITS_PER_PORT - 1 downto 0);
  signal p0_packet_length : std_logic_vector(10 downto 0);
  signal p0_request       : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal p0_valid         : std_logic_vector(NUM_PORTS - 1 downto 0);

  signal p1_data          : std_logic_vector(BITS_PER_PORT - 1 downto 0);
  signal p1_packet_length : std_logic_vector(10 downto 0);
  signal p1_request       : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal p1_valid         : std_logic_vector(NUM_PORTS - 1 downto 0);

  signal p2_data          : std_logic_vector(BITS_PER_PORT - 1 downto 0);
  signal p2_packet_length : std_logic_vector(10 downto 0);
  signal p2_request       : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal p2_valid         : std_logic_vector(NUM_PORTS - 1 downto 0);

  signal p3_data          : std_logic_vector(BITS_PER_PORT - 1 downto 0);
  signal p3_packet_length : std_logic_vector(10 downto 0);
  signal p3_request       : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal p3_valid         : std_logic_vector(NUM_PORTS - 1 downto 0);

  -- Testbench organisation
  type test_state_t is (
    RESET,
    SINGLE_VALID_WITH_MAC,
    SINGLE_VALID_NO_MAC,
    SINGLE_INVALID,
    STRESS_TEST
  );

  signal test_state : test_state_t := RESET;

begin

  -- Clock generation
  clk <= not clk after CLK_PERIOD / 2;

  -- DUT instantiation
  uut : entity work.data_parking
    port map (

      -- Clock/reset
      clk => clk,
      rst => rst,

      -- Data inputs
      input_data  => input_data,
      input_valid => input_valid,
      input_error => input_error,

      -- MAC inputs
      ready     => ready,
      dest_port => dest_port,

      -- MAC outputs
      output_valid_mac => output_valid_mac,
      dest_mac         => dest_mac,
      source_mac       => source_mac,
      src_port         => src_port,

      -- Crossbar inputs
      p0_ack => p0_ack,
      p1_ack => p1_ack,
      p2_ack => p2_ack,
      p3_ack => p3_ack,

      -- Crossbar outputs
      p0_data          => p0_data,
      p0_packet_length => p0_packet_length,
      p0_request       => p0_request,
      p0_valid         => p0_valid,

      p1_data          => p1_data,
      p1_packet_length => p1_packet_length,
      p1_request       => p1_request,
      p1_valid         => p1_valid,

      p2_data          => p2_data,
      p2_packet_length => p2_packet_length,
      p2_request       => p2_request,
      p2_valid         => p2_valid,

      p3_data          => p3_data,
      p3_packet_length => p3_packet_length,
      p3_request       => p3_request,
      p3_valid         => p3_valid
    );

  -- Stimulus process
  stim_proc : process
  begin

    -- Reset
    rst <= '0';
    wait for 50 ns;

    rst <= '1';
    wait for CLK_PERIOD * 2;

    -- ==============================================
    -- 1 valid packet, with mac response
    -- ==============================================
    test_state <= SINGLE_VALID_WITH_MAC;
    for i in 0 to 63 loop
      if (i = 30) then
        dest_port <= "1000";
        ready <= '1';
      else
        dest_port <= "0000";
        ready <= '0';
      end if;

      input_data <= std_logic_vector(to_unsigned(i, 32));
      input_valid <= "0001";

      wait for CLK_PERIOD;
    end loop;

    -- Packet is done
    input_valid <= "0000";
    wait for CLK_PERIOD;

    -- Send acknowledge
    wait for CLK_PERIOD * 10;
    p0_ack <= "1000";
    wait for CLK_PERIOD;
    p0_ack <= "0000";
    wait for CLK_PERIOD;
    wait for 80 * CLK_PERIOD;

    -- ==============================================
    -- 1 valid packet, NO mac response
    -- ==============================================
    test_state <= SINGLE_VALID_NO_MAC;
    for i in 0 to 63 loop

      input_data <= std_logic_vector(to_unsigned(i, 32));
      input_valid <= "0001";

      wait for CLK_PERIOD;
    end loop;

    -- Packet is done
    input_valid <= "0000";
    wait for CLK_PERIOD;

    -- Send acknowledge
    wait for CLK_PERIOD * 10;
    p0_ack <= "1110";
    wait for CLK_PERIOD;
    p0_ack <= "0000";
    wait for CLK_PERIOD;
    wait for 80 * CLK_PERIOD;
    
    -- ==============================================
    -- 1 invalid packet
    -- ==============================================
    test_state <= SINGLE_INVALID;
    for i in 0 to 63 loop
      if (i = 30) then
        dest_port <= "1110";
        ready <= '1';
      else
        dest_port <= "0000";
        ready <= '0';
      end if;

      input_data <= std_logic_vector(to_unsigned(i, 32));
      input_valid <= "0001";

      wait for CLK_PERIOD;
    end loop;

    -- Packet is done
    input_valid <= "0000";
    input_error <= "0001";
    wait for CLK_PERIOD;
    input_error <= "0000";
    wait for 12 * CLK_PERIOD;

    -- ==============================================
    -- Large packets stress test
    -- ==============================================
    test_state <= STRESS_TEST;
    for j in 0 to 3 loop
      for i in 0 to 1529 loop -- Max packet size
  
        input_data(7 downto 0)   <= std_logic_vector(to_unsigned(i, 8));
        input_data(15 downto 8)  <= std_logic_vector(to_unsigned(i, 8));
        input_data(23 downto 16) <= std_logic_vector(to_unsigned(i, 8));
        input_data(31 downto 24) <= std_logic_vector(to_unsigned(i, 8));
        input_valid <= "1111";
  
        wait for CLK_PERIOD;
      end loop;
  
      -- Packet is done
      input_valid <= "0000";
      wait for 12 * CLK_PERIOD;
    end loop;

    for j in 0 to 3 loop
      p0_ack <= "1110";
      p1_ack <= "1101";
      p2_ack <= "1011";
      p3_ack <= "0111";
      wait for CLK_PERIOD;
      p0_ack <= "0000";
      p1_ack <= "0000";
      p2_ack <= "0000";
      p3_ack <= "0000";
      wait for 1550 * CLK_PERIOD;
    end loop;

    wait for 20 * CLK_PERIOD;
    assert false report "Simulation finished" severity failure;

  end process;

end architecture;
