library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

-- Description:
-- Top module for the data parking module that instantiates 4 sub-modules
-- that each "park" data from the FCS/CRC module.
-- This module functions as an arbiter between the four sub-modules
-- and the MAC learning unit. The arbitration will be handled by a simple
-- round-Robin "algorithm".

entity data_parking is
  port (
    -- Clock and reset
    clk : in std_logic;
    rst : in std_logic;

    -- Data inputs
    input_data  : in std_logic_vector(DATA_BUS_WIDTH - 1 downto 0);
    input_ctrl  : in std_logic_vector(VALID_BITS - 1 downto 0);
    input_error : in std_logic_vector(ERROR_BITS - 1 downto 0);

    -- Mac inputs
    ready     : in std_logic;
    dest_port : in std_logic_vector(NUM_PORTS - 1 downto 0); -- One bit per port

    -- Mac outputs
    output_valid_mac : out std_logic;
    dest_mac         : out std_logic_vector(MAC_SIZE - 1 downto 0);
    source_mac       : out std_logic_vector(MAC_SIZE - 1 downto 0);
    src_port         : out std_logic_vector(NUM_PORTS - 1 downto 0); -- One bit per port
    
    -- Crossbar inputs
    p0_ack           : in  std_logic_vector(NUM_PORTS - 1 downto 0);
    p1_ack           : in  std_logic_vector(NUM_PORTS - 1 downto 0);
    p2_ack           : in  std_logic_vector(NUM_PORTS - 1 downto 0);
    p3_ack           : in  std_logic_vector(NUM_PORTS - 1 downto 0);

    -- Crossbar outputs
    p0_data          : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
    p0_packet_length : out std_logic_vector(10 downto 0);
    p0_request       : out std_logic_vector(NUM_PORTS - 1 downto 0);
    p0_ctrl          : out std_logic_vector(NUM_PORTS - 1 downto 0);

    p1_data          : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
    p1_packet_length : out std_logic_vector(10 downto 0);
    p1_request       : out std_logic_vector(NUM_PORTS - 1 downto 0);
    p1_ctrl          : out std_logic_vector(NUM_PORTS - 1 downto 0);

    p2_data          : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
    p2_packet_length : out std_logic_vector(10 downto 0);
    p2_request       : out std_logic_vector(NUM_PORTS - 1 downto 0);
    p2_ctrl          : out std_logic_vector(NUM_PORTS - 1 downto 0);

    p3_data          : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
    p3_packet_length : out std_logic_vector(10 downto 0);
    p3_request       : out std_logic_vector(NUM_PORTS - 1 downto 0);
    p3_ctrl          : out std_logic_vector(NUM_PORTS - 1 downto 0)
  );
end entity data_parking;

architecture rtl of data_parking is
  -- MAC learning unit slice connections
  signal p0_ready            : std_logic;
  signal p0_output_valid_mac : std_logic;
  signal p0_dest_port        : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal p0_dest_mac         : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal p0_source_mac       : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal p0_src_port         : std_logic_vector(NUM_PORTS - 1 downto 0);
  
  signal p1_ready            : std_logic;
  signal p1_output_valid_mac : std_logic;
  signal p1_dest_port        : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal p1_dest_mac         : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal p1_source_mac       : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal p1_src_port         : std_logic_vector(NUM_PORTS - 1 downto 0);
  
  signal p2_ready            : std_logic;
  signal p2_output_valid_mac : std_logic;
  signal p2_dest_port        : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal p2_dest_mac         : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal p2_source_mac       : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal p2_src_port         : std_logic_vector(NUM_PORTS - 1 downto 0);

  signal p3_ready            : std_logic;
  signal p3_output_valid_mac : std_logic;
  signal p3_dest_port        : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal p3_dest_mac         : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal p3_source_mac       : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal p3_src_port         : std_logic_vector(NUM_PORTS - 1 downto 0);

  -- FSM signals
  type round_robin_type is (PORT0, PORT0_WAIT, PORT1, PORT1_WAIT, PORT2, PORT2_WAIT, PORT3, PORT3_WAIT);
  signal round_robin : round_robin_type;

begin
  process (clk, rst)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        -- Reset logicS
        round_robin <= PORT0;
      else

        -- Standard FSM values
        p0_ready <= '0';
        p0_dest_port <= "1110";
        p1_ready <= '0';
        p1_dest_port <= "1101";
        p2_ready <= '0';
        p2_dest_port <= "1011";
        p3_ready <= '0';
        p3_dest_port <= "0111";
        
        case round_robin is
          when PORT0 =>
            if (ready = '1') then
              p0_ready <= ready;
              p0_dest_port <= dest_port;

              output_valid_mac <= '0';
              dest_mac         <= p1_dest_mac;
              source_mac       <= p1_source_mac;
              src_port         <= p1_src_port;

              round_robin <= PORT0_WAIT;
            elsif (p0_output_valid_mac = '1') then
              output_valid_mac <= p0_output_valid_mac;
              dest_mac         <= p0_dest_mac;
              source_mac       <= p0_source_mac;
              src_port         <= p0_src_port;

              round_robin <= PORT0;
            else
              output_valid_mac <= p1_output_valid_mac;
              dest_mac         <= p1_dest_mac;
              source_mac       <= p1_source_mac;
              src_port         <= p1_src_port;

              round_robin <= PORT1;
            end if;

          when PORT0_WAIT =>
            round_robin <= PORT1;
          
          when PORT1 =>
            if (ready = '1') then
              p1_ready <= ready;
              p1_dest_port <= dest_port;

              output_valid_mac <= '0';
              dest_mac         <= p2_dest_mac;
              source_mac       <= p2_source_mac;
              src_port         <= p2_src_port;

              round_robin <= PORT1_WAIT;
            elsif (p1_output_valid_mac = '1') then
              output_valid_mac <= p1_output_valid_mac;
              dest_mac         <= p1_dest_mac;
              source_mac       <= p1_source_mac;
              src_port         <= p1_src_port;

              round_robin <= PORT1;
            else
              output_valid_mac <= p2_output_valid_mac;
              dest_mac         <= p2_dest_mac;
              source_mac       <= p2_source_mac;
              src_port         <= p2_src_port;

              round_robin <= PORT2;
            end if;
          
          when PORT1_WAIT =>
            round_robin <= PORT2;

          when PORT2 =>
            if (ready = '1') then
              p2_ready <= ready;
              p2_dest_port <= dest_port;

              output_valid_mac <= '0';
              dest_mac         <= p3_dest_mac;
              source_mac       <= p3_source_mac;
              src_port         <= p3_src_port;

              round_robin <= PORT2_WAIT;
            elsif (p2_output_valid_mac = '1') then
              output_valid_mac <= p2_output_valid_mac;
              dest_mac         <= p2_dest_mac;
              source_mac       <= p2_source_mac;
              src_port         <= p2_src_port;

              round_robin <= PORT2;
            else
              output_valid_mac <= p3_output_valid_mac;
              dest_mac         <= p3_dest_mac;
              source_mac       <= p3_source_mac;
              src_port         <= p3_src_port;

              round_robin <= PORT3;
            end if;

          when PORT2_WAIT =>
            round_robin <= PORT3;

          when PORT3 =>
            if (ready = '1') then
              p3_ready <= ready;
              p3_dest_port <= dest_port;

              output_valid_mac <= '0';
              dest_mac         <= p0_dest_mac;
              source_mac       <= p0_source_mac;
              src_port         <= p0_src_port;

              round_robin <= PORT3_WAIT;
            elsif (p3_output_valid_mac = '1') then
              output_valid_mac <= p3_output_valid_mac;
              dest_mac         <= p3_dest_mac;
              source_mac       <= p3_source_mac;
              src_port         <= p3_src_port;

              round_robin <= PORT3;
            else
              output_valid_mac <= p0_output_valid_mac;
              dest_mac         <= p0_dest_mac;
              source_mac       <= p0_source_mac;
              src_port         <= p0_src_port;

              round_robin <= PORT0;
            end if;
          
          when PORT3_WAIT =>
            round_robin <= PORT0;
        end case;

      end if;
    end if;
  end process;


  ------------------------------------------------------------------------------
  -- Port 0 slice
  ------------------------------------------------------------------------------
  data_parking_slice_0 : entity work.data_parking_slice
    generic map (
      STANDARD_DEST_PORT => "1110",
      SOURCE_PORT        => "0001"
    )
    port map (
      -- Clock and reset
      clk => clk,
      rst => rst,

      -- Data input
      input_data  => input_data(BITS_PER_PORT - 1 downto 0),
      input_valid => input_ctrl(0),
      input_error => input_error(0),

      -- Input from MAC
      mac_ready => p0_ready,
      dest_port => p0_dest_port,

      -- Outputs to MAC
      output_valid_mac => p0_output_valid_mac,
      src_port         => p0_src_port,
      dest_mac_out     => p0_dest_mac,
      src_mac_out      => p0_source_mac,

      -- Crossbar IO
      crossbar_ack          => p0_ack,
      crossbar_data         => p0_data,
      crossbar_request_size => p0_packet_length,
      crossbar_send_request => p0_request,
      crossbar_valid        => p0_ctrl
    );

  ------------------------------------------------------------------------------
  -- Port 1 slice
  ------------------------------------------------------------------------------
  data_parking_slice_1 : entity work.data_parking_slice
    generic map (
      STANDARD_DEST_PORT => "1101",
      SOURCE_PORT        => "0010"
    )
    port map (
      -- Clock and reset
      clk => clk,
      rst => rst,

      -- Data input
      input_data  => input_data((2 * BITS_PER_PORT) - 1 downto BITS_PER_PORT),
      input_valid => input_ctrl(1),
      input_error => input_error(1),

      -- Input from MAC
      mac_ready => p1_ready,
      dest_port => p1_dest_port,

      -- Outputs to MAC
      output_valid_mac => p1_output_valid_mac,
      src_port         => p1_src_port,
      dest_mac_out     => p1_dest_mac,
      src_mac_out      => p1_source_mac,

      -- Crossbar IO
      crossbar_ack          => p1_ack,
      crossbar_data         => p1_data,
      crossbar_request_size => p1_packet_length,
      crossbar_send_request => p1_request,
      crossbar_valid        => p1_ctrl
    );

  ------------------------------------------------------------------------------
  -- Port 2 slice
  ------------------------------------------------------------------------------
  data_parking_slice_2 : entity work.data_parking_slice
    generic map (
      STANDARD_DEST_PORT => "1011",
      SOURCE_PORT        => "0100"
    )
    port map (
      -- Clock and reset
      clk => clk,
      rst => rst,

      -- Data input
      input_data  => input_data((3 * BITS_PER_PORT) - 1 downto (2 * BITS_PER_PORT)),
      input_valid => input_ctrl(2),
      input_error => input_error(2),

      -- Input from MAC
      mac_ready => p2_ready,
      dest_port => p2_dest_port,

      -- Outputs to MAC
      output_valid_mac => p2_output_valid_mac,
      src_port         => p2_src_port,
      dest_mac_out     => p2_dest_mac,
      src_mac_out      => p2_source_mac,

      -- Crossbar IO
      crossbar_ack          => p2_ack,
      crossbar_data         => p2_data,
      crossbar_request_size => p2_packet_length,
      crossbar_send_request => p2_request,
      crossbar_valid        => p2_ctrl
    );

  ------------------------------------------------------------------------------
  -- Port 3 slice
  ------------------------------------------------------------------------------
  data_parking_slice_3 : entity work.data_parking_slice
    generic map (
      STANDARD_DEST_PORT => "0111",
      SOURCE_PORT        => "1000"
    )
    port map (
      -- Clock and reset
      clk => clk,
      rst => rst,

      -- Data input
      input_data  => input_data((4 * BITS_PER_PORT) - 1 downto (3 * BITS_PER_PORT)),
      input_valid => input_ctrl(3),
      input_error => input_error(3),

      -- Input from MAC
      mac_ready => p3_ready,
      dest_port => p3_dest_port,

      -- Outputs to MAC
      output_valid_mac => p3_output_valid_mac,
      src_port         => p3_src_port,
      dest_mac_out     => p3_dest_mac,
      src_mac_out      => p3_source_mac,

      -- Crossbar IO
      crossbar_ack          => p3_ack,
      crossbar_data         => p3_data,
      crossbar_request_size => p3_packet_length,
      crossbar_send_request => p3_request,
      crossbar_valid        => p3_ctrl
    );
end architecture rtl;