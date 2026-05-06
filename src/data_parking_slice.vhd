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
    clk: in std_logic;
    rst: in std_logic;

    -- Data input
    input_data  : in std_logic_vector(BITS_PER_PORT - 1 downto 0);
    input_valid : in std_logic;
    input_error : in std_logic;

    -- Input from MAC
    mac_ready       : in std_logic;
    dest_port       : in std_logic_vector(NUM_PORTS - 1 downto 0);
    
    -- Outputs to MAC
    output_valid_mac : out std_logic;
    src_port         : out std_logic_vector(NUM_PORTS - 1 downto 0);
    dest_mac         : out std_logic_vector(MAC_SIZE - 1 downto 0);
    src_mac          : out std_logic_vector(MAC_SIZE - 1 downto 0);

    -- Outputs to crossbar
    output_data      : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
    output_valid     : out std_logic
  );

end entity data_parking_slice;


architecture rtl of data_parking_slice is
  signal packet_cnt       : std_logic_vector(2 downto 0);
  signal shifted_packet   : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal input_valid_prev : std_logic;
  signal processed        : std_logic;
  signal rdy_to_process   : std_logic;

  -- FSM signals
  type packet_state_type is (IDLE, PREAMBLE, MAC_DEST, MAC_SOURCE);
  signal packet_state : packet_state_type;

begin
  shifted_packet <= shift_left(unsigned(input_data), BITS_PER_PORT*unsigned(packet_cnt));

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        packet_cnt <= (others => '0');
        dest_port <= STANDARD_DEST_PORT;

      else
        output_valid_mac <= rdy_to_process and not(processed);
        src_port <= SOURCE_PORT;

        input_valid_prev <= input_valid;

        if mac_ready = '1' then
          processed <= '1';
          dest_port <= 
        end if;
        
        case packet_state is
          is IDLE =>
            if (input_data = '1' and input_data_prev = '0') then
              packet_cnt <= '0';
              processed <= '0';
              packet_state <= PREAMBLE;
            else
              packet_state <= IDLE;
            end if;

          is PREAMBLE =>
            if packet_cnt = 7 then
              packet_cnt <= '0';
              dest_mac <= (others => '0');
              src_mac <= (others => '0');
              packet_state <= MAC_DEST;
            else
              packet_cnt <= packet_cnt + 1;
              packet_state <= PREAMBLE;
            end if;

          is MAC_DEST =>
            if packet_cnt = 7 then
              packet_cnt <= '0';
              dest_mac <= dest_mac | shifted_packet;
              packet_state <= MAC_SOURCE;
            else
              packet_cnt <= packet_cnt + 1;
              dest_mac <= dest_mac | shifted_packet;
              packet_state <= MAC_DEST;
            end if;

          is MAC_SOURCE =>
            if packet_cnt = 7 then
              packet_cnt <= '0';
              src_mac <= src_mac | shifted_packet;
              rdy_to_process <= '1';
              packet_state <= IDLE;
            else
              packet_cnt <= packet_cnt + 1;
              src_mac <= src_mac | shifted_packet;
              packet_state <= MAC_SOURCE;
            end if;

        end case;

        -- Update MAC src and dest registers


        -- Set src port register (constant value)
      end if;
    end if;
  end process;

end architecture rtl;