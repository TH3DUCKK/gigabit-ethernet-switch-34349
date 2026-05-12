library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

-- Description:
-- The design requires 4 of these "slices" to be instantiated.
-- Each will take input directly from the FCS/CRC module and load
-- data into a FIFO. While this is happening, it will extract
-- information used for MAC learning, and if an error is found
-- by the FCS/CRC module, the data will be marked to be discarded.

entity data_parking_slice is
  generic(
    STANDARD_DEST_PORT : std_logic_vector(NUM_PORTS - 1 downto 0) := "1111";
    SOURCE_PORT        : std_logic_vector(NUM_PORTS - 1 downto 0) := "0000"
  );
  port(
    -- Clock and reset
    clk : in std_logic;
    rst : in std_logic;

    -- Data input
    input_data  : in std_logic_vector(BITS_PER_PORT - 1 downto 0);
    input_valid : in std_logic;
    input_error : in std_logic;

    -- Input from MAC
    mac_ready : in std_logic;
    dest_port : in std_logic_vector(NUM_PORTS - 1 downto 0);
    
    -- Outputs to MAC
    output_valid_mac : out std_logic;
    src_port         : out std_logic_vector(NUM_PORTS - 1 downto 0);
    dest_mac_out     : out std_logic_vector(MAC_SIZE - 1 downto 0);
    src_mac_out      : out std_logic_vector(MAC_SIZE - 1 downto 0);

    -- Crossbar IO
    crossbar_ack          : in  std_logic_vector(NUM_PORTS - 1 downto 0);
    crossbar_data         : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
    crossbar_request_size : out std_logic_vector(10 downto 0);
    crossbar_send_request : out std_logic_vector(NUM_PORTS - 1 downto 0);
    crossbar_valid        : out std_logic
  );

end entity data_parking_slice;


architecture rtl of data_parking_slice is
  signal processed        : std_logic;
  signal rdy_to_process   : std_logic;
  signal input_valid_prev : std_logic;
  signal input_data_prev  : std_logic_vector(BITS_PER_PORT - 1 downto 0);
  signal packet_cnt       : std_logic_vector(2 downto 0);
  signal shifted_packet   : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal dest_mac         : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal src_mac          : std_logic_vector(MAC_SIZE - 1 downto 0);

  -- FSM signals
  type packet_state_type is (IDLE, PREAMBLE, MAC_DEST, MAC_SOURCE);
  signal packet_state : packet_state_type;

  -- Double fifo signals
  signal dest_port_fifo       : std_logic_vector(NUM_PORTS-1 downto 0);
  signal dest_port_valid_fifo : std_logic;

begin

  -- Double FIFO instantiation
  double_fifo : entity work.double_fifo
    port map (
      clk             => clk,
      rst             => rst,

      wr_en           => input_valid,
      write_data      => input_data,
      error_data      => input_error,

      dest_port       => dest_port_fifo,
      dest_port_valid => dest_port_valid_fifo,

      request_ack     => crossbar_ack,
      out_data_valid  => crossbar_valid,
      send_request    => crossbar_send_request,
      request_size    => crossbar_request_size,
      packet_data     => crossbar_data
    );

  shifted_packet <= std_logic_vector(shift_left(resize(unsigned(input_data_prev), shifted_packet'length),to_integer(unsigned(packet_cnt)) * BITS_PER_PORT));
  dest_mac_out <= dest_mac;
  src_mac_out <= src_mac;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        packet_cnt <= (others => '0');
        dest_port_fifo <= STANDARD_DEST_PORT;
        src_port <= SOURCE_PORT;
        dest_mac <= (others => '0');
        src_mac <= (others => '0');
      else
        output_valid_mac <= rdy_to_process and not(processed);
        input_valid_prev <= input_valid;
        input_data_prev <= input_data;

        if mac_ready = '1' then
          processed <= '1';
          dest_port_fifo <= dest_port;
          dest_port_valid_fifo <= '1';
        else
          dest_port_fifo <= STANDARD_DEST_PORT;
          dest_port_valid_fifo <= '0';
        end if;
        
        case packet_state is
          when IDLE =>
            if (input_valid = '1' and input_valid_prev = '0') then
              packet_cnt <= (others => '0');
              processed <= '0';
              packet_state <= PREAMBLE;
            else
              packet_state <= IDLE;
            end if;

          when PREAMBLE =>
            if unsigned(packet_cnt) = 7 then
              packet_cnt <= (others => '0');
              dest_mac <= (others => '0');
              src_mac <= (others => '0');
              packet_state <= MAC_DEST;
            else
              packet_cnt <= std_logic_vector(unsigned(packet_cnt) + 1);
              packet_state <= PREAMBLE;
            end if;

          when MAC_DEST =>
            if unsigned(packet_cnt) = 5 then
              packet_cnt <= (others => '0');
              dest_mac <= dest_mac or shifted_packet;
              packet_state <= MAC_SOURCE;
            else
              packet_cnt <= std_logic_vector(unsigned(packet_cnt) + 1);
              dest_mac <= dest_mac or shifted_packet;
              packet_state <= MAC_DEST;
            end if;

          when MAC_SOURCE =>
            if unsigned(packet_cnt) = 5 then
              packet_cnt <= (others => '0');
              src_mac <= src_mac or shifted_packet;
              rdy_to_process <= '1';
              packet_state <= IDLE;
            else
              packet_cnt <= std_logic_vector(unsigned(packet_cnt) + 1);
              src_mac <= src_mac or shifted_packet;
              packet_state <= MAC_SOURCE;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture rtl;