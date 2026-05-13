library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

use work.constants.all;

entity switchcore is

  port (
    clk   : in std_logic;
    reset : in std_logic;

    --Activity indicators
    link_sync : in std_logic_vector(3 downto 0); --High indicates a peer connection at the physical layer. 

    --Four GMII interfaces
    tx_data : out std_logic_vector(31 downto 0); --(7 downto 0)=TXD0...(31 downto 24=TXD3)
    tx_ctrl : out std_logic_vector(3 downto 0); --(0)=TXC0...(3=TXC3)
    rx_data : in std_logic_vector(31 downto 0); --(7 downto 0)=RXD0...(31 downto 24=RXD3)
    rx_ctrl : in std_logic_vector(3 downto 0) --(0)=RXC0...(3=RXC3)
  );

end switchcore;

architecture arch of switchcore is

  -- Component declarations
  component fcs is
    port (
      -- Clock and reset
      clk : in std_logic;
      rst : in std_logic;
      -- Data inputs
      input_data  : in std_logic_vector(DATA_BUS_WIDTH - 1 downto 0);
      input_valid : in std_logic_vector(VALID_BITS - 1 downto 0);
      -- Data outputs
      output_data  : out std_logic_vector(DATA_BUS_WIDTH - 1 downto 0);
      output_valid : out std_logic_vector(VALID_BITS - 1 downto 0);
      output_error : out std_logic_vector(ERROR_BITS - 1 downto 0)
    );
  end component fcs;

  component data_parking is
    port (
      -- Clock and reset
      clk : in std_logic;
      rst : in std_logic;

      -- Data inputs
      input_data  : in std_logic_vector(DATA_BUS_WIDTH - 1 downto 0);
      input_valid : in std_logic_vector(VALID_BITS - 1 downto 0);
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
      p0_ack : in std_logic_vector(NUM_PORTS - 1 downto 0);
      p1_ack : in std_logic_vector(NUM_PORTS - 1 downto 0);
      p2_ack : in std_logic_vector(NUM_PORTS - 1 downto 0);
      p3_ack : in std_logic_vector(NUM_PORTS - 1 downto 0);

      -- Crossbar outputs
      p0_data          : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
      p0_packet_length : out std_logic_vector(10 downto 0);
      p0_request       : out std_logic_vector(NUM_PORTS - 1 downto 0);
      p0_valid         : out std_logic;

      p1_data          : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
      p1_packet_length : out std_logic_vector(10 downto 0);
      p1_request       : out std_logic_vector(NUM_PORTS - 1 downto 0);
      p1_valid         : out std_logic;

      p2_data          : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
      p2_packet_length : out std_logic_vector(10 downto 0);
      p2_request       : out std_logic_vector(NUM_PORTS - 1 downto 0);
      p2_valid         : out std_logic;

      p3_data          : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
      p3_packet_length : out std_logic_vector(10 downto 0);
      p3_request       : out std_logic_vector(NUM_PORTS - 1 downto 0);
      p3_valid         : out std_logic
    );
  end component data_parking;

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

  component crossbar is
    port (
      -- Clock and reset
      clk : in std_logic;
      rst : in std_logic;

      -- PORT 0
      frame_data_0       : in std_logic_vector(31 downto 0);
      frame_data_valid_0 : in std_logic_vector(3 downto 0);
      meta_data_0        : in std_logic_vector(63 downto 0);
      meta_data_valid_0  : in std_logic_vector(3 downto 0);

      port_data_out_0   : out std_logic_vector(7 downto 0);
      port_data_valid_0 : out std_logic_vector(3 downto 0);
      enough_space_0    : out std_logic_vector(3 downto 0);

      -- PORT 1
      frame_data_1       : in std_logic_vector(31 downto 0);
      frame_data_valid_1 : in std_logic_vector(3 downto 0);
      meta_data_1        : in std_logic_vector(63 downto 0);
      meta_data_valid_1  : in std_logic_vector(3 downto 0);

      port_data_out_1   : out std_logic_vector(7 downto 0);
      port_data_valid_1 : out std_logic_vector(3 downto 0);
      enough_space_1    : out std_logic_vector(3 downto 0);

      -- PORT 2
      frame_data_2       : in std_logic_vector(31 downto 0);
      frame_data_valid_2 : in std_logic_vector(3 downto 0);
      meta_data_2        : in std_logic_vector(63 downto 0);
      meta_data_valid_2  : in std_logic_vector(3 downto 0);

      port_data_out_2   : out std_logic_vector(7 downto 0);
      port_data_valid_2 : out std_logic_vector(3 downto 0);
      enough_space_2    : out std_logic_vector(3 downto 0);

      -- PORT 3
      frame_data_3       : in std_logic_vector(31 downto 0);
      frame_data_valid_3 : in std_logic_vector(3 downto 0);
      meta_data_3        : in std_logic_vector(63 downto 0);
      meta_data_valid_3  : in std_logic_vector(3 downto 0);

      port_data_out_3   : out std_logic_vector(7 downto 0);
      port_data_valid_3 : out std_logic_vector(3 downto 0);
      enough_space_3    : out std_logic_vector(3 downto 0)

    );
  end component crossbar;


	-- Wires for interconnectiong components

begin
  internalloop : process (clk, reset)
  begin

    if (reset = '0') then
      tx_data(7 downto 0)  <= (others => '0');
      tx_data(15 downto 8) <= (others => '0');
      tx_ctrl(0)           <= '0';
      tx_ctrl(1)           <= '0';

    elsif (rising_edge(clk)) then

      tx_data(7 downto 0)  <= rx_data(15 downto 8);
      tx_data(15 downto 8) <= rx_data(7 downto 0);
      tx_ctrl(0)           <= rx_ctrl(1);
      tx_ctrl(1)           <= rx_ctrl(0);
    end if;

  end process;
end arch;
