LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.constants.all;

-- Description
-- This module consists of two FIFOs, one large and one small.
-- The small FIFO contains metadata about the contents of the
-- larger FIFO. This module automatically deletes incorrect data
-- in the large FIFO is an error is detected.

entity double_fifo is
  port (
    clk             : in  std_logic;
    rst             : in  std_logic;

    -- Write interface
    wr_en           : in  std_logic;
    write_data      : in  std_logic_vector(BITS_PER_PORT-1 downto 0);
    error_data      : in  std_logic;

    -- Destination input
    dest_port       : in  std_logic_vector(NUM_PORTS-1 downto 0);
    dest_port_valid : in std_logic;

    -- Request to send
    request_ack     : in  std_logic_vector(NUM_PORTS-1 downto 0);
    out_data_valid  : out std_logic;
    send_request    : out std_logic_vector(NUM_PORTS-1 downto 0);
    packet_data     : out std_logic_vector(BITS_PER_PORT-1 downto 0)
  );
end entity double_fifo;

architecture rtl of double_fifo is
  -- Signals for writing data
  signal write_data_in      : std_logic_vector(7 downto 0);
  signal write_data_in_prev : std_logic_vector(7 downto 0);
  signal wr_en_in           : std_logic;
  signal wr_en_in_prev      : std_logic;
  signal packet_length_cnt  : std_logic_vector(10 downto 0);
  signal error_data_in      : std_logic;
  signal error_data_in_del  : std_logic;

  -- Signals for reading and transfering data
  signal packets_sent     : std_logic_vector(10 downto 0);
  signal packet_amount    : std_logic_vector(10 downto 0);
  signal send_request_out : std_logic_vector(NUM_PORTS-1 downto 0);

  -- FSM signals
  type write_state_type is (IDLE, WRITING, ERROR_CHECK, FULL_MID_WRITE, STILL_FULL);
  signal write_state : write_state_type;

  type read_state_type is (IDLE, WAIT_FOR_META, READ_META, WAIT_FOR_ACK, SEND_DATA);
  signal read_state : read_state_type;

  -- ---------- SMALL FIFO SIGNALS ----------
  signal wr_en_meta      : std_logic;
  signal write_data_meta : std_logic_vector(15 downto 0);

  signal rd_en_meta      : std_logic;
  signal read_data_meta  : std_logic_vector(15 downto 0);

  signal full_meta       : std_logic;
  signal empty_meta      : std_logic;

  -- ---------- LARGE FIFO SIGNALS ----------
  signal wr_en_packet         : std_logic;
  --signal write_data_packet    : std_logic_vector(7 downto 0);

  signal rd_en_packet         : std_logic;
  signal read_data_packet     : std_logic_vector(7 downto 0);

  signal jump_read_ptr_packet : std_logic;
  signal jump_size_packet     : std_logic_vector(10 downto 0);

  signal full_packet          : std_logic;
  signal almost_full_packet   : std_logic;
  signal empty_packet         : std_logic;

  component sync_fifo_64
    generic (
      DATA_WIDTH : integer := 16;
      DEPTH      : integer := 64;
      ADDR_WIDTH : integer := 6
    );
    port (
      clk        : in  std_logic;
      rst        : in  std_logic;
      wr_en      : in  std_logic;
      write_data : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      rd_en      : in  std_logic;
      read_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);
      full       : out std_logic;
      empty      : out std_logic
    );
  end component;

  component sync_fifo_4096
    generic (
      DATA_WIDTH : integer := 8;
      DEPTH      : integer := 4096;
      ADDR_WIDTH : integer := 12
    );
    port (
      clk           : in  std_logic;
      rst           : in  std_logic;
      wr_en         : in  std_logic;
      write_data    : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      rd_en         : in  std_logic;
      read_data     : out std_logic_vector(DATA_WIDTH-1 downto 0);
      jump_read_ptr : in  std_logic;
      jump_size     : in  std_logic_vector(10 downto 0);
      full          : out std_logic;
      almost_full   : out std_logic;
      empty         : out std_logic
    );
  end component;
begin

  packet_data <= read_data_packet;

  -- WRITE FSM STATES:
  -- IDLE: Nothing is happening
  -- WRITING: Writing to the data FIFO
  -- ERROR_CHECK: Writing is done, check if error has occured
  -- FULL_MID_WRITE: FIFO has become full in the middle of writing
  -- STILL_FULL: FIFO is still full

  -- Write process
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        write_data_meta <= (others => '0');
        packet_length_cnt <= (others => '0');
        wr_en_packet <= '0';
        write_state <= IDLE;
      else
        write_data_in <= write_data;
        write_data_in_prev <= write_data_in;
        wr_en_in <= wr_en;
        wr_en_in_prev <= wr_en_in;
        error_data_in <= error_data;
        error_data_in_del <= error_data_in;
        
        -- Update destination port register
        if dest_port_valid = '1' then
          write_data_meta(14 downto 11) <= dest_port;
        end if;
        
        -- Standard FSM values
        wr_en_meta <= '0';

        case write_state is
          when IDLE =>
            if (wr_en_in = '1' and wr_en_in_prev = '0') then
              packet_length_cnt <= "00000000001";
              wr_en_packet <= '1';
              write_state <= WRITING;
            else
              wr_en_packet <= '0';
              write_state <= IDLE;
            end if;
          
          when WRITING =>
            if almost_full_packet = '1' then
              wr_en_packet <= '0';
              write_data_meta(15) <= '1';
              write_data_meta(10 downto 0) <= packet_length_cnt + 1; -- should maybe be packet_length_cnt
              write_state <= FULL_MID_WRITE;
            elsif almost_full_packet = '0' and (wr_en_in = '0' and wr_en_in_prev = '1') then
              wr_en_packet <= '0';
              write_state <= ERROR_CHECK;
            else
              wr_en_packet <= '1';
              packet_length_cnt <= packet_length_cnt + 1;
              write_state <= WRITING;
            end if;

          when ERROR_CHECK =>
            write_data_meta(15) <= error_data_in_del;
            write_data_meta(10 downto 0) <= packet_length_cnt;
            wr_en_meta <= '1';
            write_state <= IDLE;

          when FULL_MID_WRITE =>
            wr_en_meta <= '1';
            write_state <= STILL_FULL;

          when STILL_FULL =>
            if full_packet = '0' and wr_en = '0' then
              write_state <= IDLE;
            else
              write_state <= STILL_FULL;
            end if;
        end case;

      end if;
    end if;
  end process;

  -- READ FSM STATES:
  -- IDLE: Nothing is happening
  -- WAIT_FOR_META: Wait 1 cycle for meta data to be ready
  -- READ_META: Reading metadata
  -- WAIT_FOR_ACK: Request has been sent, waiting for acknowledge
  -- SEND_DATA: Transferring packet data

  -- Read process
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        out_data_valid <= '0';
        send_request_out <= (others => '0');
        packets_sent <= (others => '0');
        packet_amount <= (others => '0');
        read_state <= IDLE;
      else

        send_request <= send_request_out;


        -- Standard FSM values
        rd_en_meta <= '0';
        rd_en_packet <= '0';
        jump_read_ptr_packet <= '0';
        jump_size_packet <= (others => '0');

        case read_state is
          when IDLE =>
            if empty_meta = '0' then
              rd_en_meta <= '1';
              read_state <= WAIT_FOR_META;
            else
              read_state <= IDLE;
            end if;

          when WAIT_FOR_META =>
            read_state <= READ_META;

          when READ_META =>
            if read_data_meta(15) = '1' then -- Error found, delete from large fifo and return to idle
              jump_read_ptr_packet <= '1';
              jump_size_packet <= read_data_meta(10 downto 0);
              read_state <= IDLE;
            else
              send_request_out <= read_data_meta(14 downto 11);
              packet_amount <= read_data_meta(10 downto 0);
              read_state <= WAIT_FOR_ACK;
            end if;
          
          when WAIT_FOR_ACK =>
            if send_request_out = request_ack then
              rd_en_packet <= '1';
              packets_sent <= "00000000000";
              read_state <= SEND_DATA;
            else
              read_state <= WAIT_FOR_ACK;
            end if;
          
          when SEND_DATA =>
            if packets_sent = packet_amount then
              packets_sent <= (others => '0');
              out_data_valid <= '0';
              read_state <= IDLE;
            elsif packets_sent = (packet_amount - 1) then
              packets_sent <= packets_sent + 1;
              out_data_valid <= '1';
              rd_en_packet <= '0';
              read_state <= SEND_DATA;
            else
              packets_sent <= packets_sent + 1;
              out_data_valid <= '1';
              rd_en_packet <= '1';
              read_state <= SEND_DATA;
            end if;
        end case;
        
      end if;
    end if;
  end process;

  -- ---------- FIFO INSTANTIATIONS ----------
  fifo_inst_meta : sync_fifo_64
  generic map (
    DATA_WIDTH => 16,
    DEPTH      => 64,
    ADDR_WIDTH => 6
  )
  port map (
    clk        => clk,
    rst        => rst,
    wr_en      => wr_en_meta,
    write_data => write_data_meta,
    rd_en      => rd_en_meta,
    read_data  => read_data_meta,
    full       => full_meta,
    empty      => empty_meta
  );

  fifo_inst_packet : sync_fifo_4096
  generic map (
    DATA_WIDTH => 8,
    DEPTH      => 4096,
    ADDR_WIDTH => 12
  )
  port map (
    clk           => clk,
    rst           => rst,
    wr_en         => wr_en_packet,
    write_data    => write_data_in_prev,
    rd_en         => rd_en_packet,
    read_data     => read_data_packet,
    jump_read_ptr => jump_read_ptr_packet,
    jump_size     => jump_size_packet,
    full          => full_packet,
    almost_full   => almost_full_packet,
    empty         => empty_packet
  );

end architecture rtl;