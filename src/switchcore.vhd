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

  -------------------------------------------------------------------
  -- COMPONENT DECLARATIONS (Assuming these remain unchanged from your file)
  -------------------------------------------------------------------
  component fcs is
    port (
      clk          : in std_logic;
      rst          : in std_logic;
      input_data   : in std_logic_vector(DATA_BUS_WIDTH - 1 downto 0);
      input_valid  : in std_logic_vector(VALID_BITS - 1 downto 0);
      output_data  : out std_logic_vector(DATA_BUS_WIDTH - 1 downto 0);
      output_valid : out std_logic_vector(VALID_BITS - 1 downto 0);
      output_error : out std_logic_vector(ERROR_BITS - 1 downto 0)
    );
  end component fcs;

  component data_parking is
    port (
      clk              : in std_logic;
      rst              : in std_logic;
      input_data       : in std_logic_vector(DATA_BUS_WIDTH - 1 downto 0);
      input_valid      : in std_logic_vector(VALID_BITS - 1 downto 0);
      input_error      : in std_logic_vector(ERROR_BITS - 1 downto 0);
      ready            : in std_logic;
      dest_port        : in std_logic_vector(NUM_PORTS - 1 downto 0);
      output_valid_mac : out std_logic;
      dest_mac         : out std_logic_vector(MAC_SIZE - 1 downto 0);
      source_mac       : out std_logic_vector(MAC_SIZE - 1 downto 0);
      src_port         : out std_logic_vector(NUM_PORTS - 1 downto 0);
      p0_ack           : in std_logic_vector(NUM_PORTS - 1 downto 0);
      p1_ack           : in std_logic_vector(NUM_PORTS - 1 downto 0);
      p2_ack           : in std_logic_vector(NUM_PORTS - 1 downto 0);
      p3_ack           : in std_logic_vector(NUM_PORTS - 1 downto 0);
      p0_data          : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
      p0_packet_length : out std_logic_vector(10 downto 0);
      p0_request       : out std_logic_vector(NUM_PORTS - 1 downto 0);
      p0_valid         : out std_logic_vector(NUM_PORTS - 1 downto 0);
      p1_data          : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
      p1_packet_length : out std_logic_vector(10 downto 0);
      p1_request       : out std_logic_vector(NUM_PORTS - 1 downto 0);
      p1_valid         : out std_logic_vector(NUM_PORTS - 1 downto 0);
      p2_data          : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
      p2_packet_length : out std_logic_vector(10 downto 0);
      p2_request       : out std_logic_vector(NUM_PORTS - 1 downto 0);
      p2_valid         : out std_logic_vector(NUM_PORTS - 1 downto 0);
      p3_data          : out std_logic_vector(BITS_PER_PORT - 1 downto 0);
      p3_packet_length : out std_logic_vector(10 downto 0);
      p3_request       : out std_logic_vector(NUM_PORTS - 1 downto 0);
      p3_valid         : out std_logic_vector(NUM_PORTS - 1 downto 0)
    );
  end component data_parking;

  component mac_learning_top is
    port (
      clk        : in std_logic;
      rst        : in std_logic;
      valid      : in std_logic;
      src_port   : in std_logic_vector(NUM_PORTS - 1 downto 0);
      source_mac : in std_logic_vector(MAC_SIZE - 1 downto 0);
      dest_mac   : in std_logic_vector(MAC_SIZE - 1 downto 0);
      ready      : out std_logic;
      dest_port  : out std_logic_vector(NUM_PORTS - 1 downto 0)
    );
  end component mac_learning_top;

  component crossbar is
    port (
      clk : in std_logic;
      rst : in std_logic;

      frame_data_0       : in std_logic_vector(31 downto 0);
      frame_data_valid_0 : in std_logic_vector(3 downto 0);
      meta_data_0        : in std_logic_vector(63 downto 0);
      meta_data_valid_0  : in std_logic_vector(3 downto 0);
      port_data_out_0    : out std_logic_vector(7 downto 0);
      port_data_valid_0  : out std_logic_vector(3 downto 0);
      enough_space_0     : out std_logic_vector(3 downto 0);

      frame_data_1       : in std_logic_vector(31 downto 0);
      frame_data_valid_1 : in std_logic_vector(3 downto 0);
      meta_data_1        : in std_logic_vector(63 downto 0);
      meta_data_valid_1  : in std_logic_vector(3 downto 0);
      port_data_out_1    : out std_logic_vector(7 downto 0);
      port_data_valid_1  : out std_logic_vector(3 downto 0);
      enough_space_1     : out std_logic_vector(3 downto 0);

      frame_data_2       : in std_logic_vector(31 downto 0);
      frame_data_valid_2 : in std_logic_vector(3 downto 0);
      meta_data_2        : in std_logic_vector(63 downto 0);
      meta_data_valid_2  : in std_logic_vector(3 downto 0);
      port_data_out_2    : out std_logic_vector(7 downto 0);
      port_data_valid_2  : out std_logic_vector(3 downto 0);
      enough_space_2     : out std_logic_vector(3 downto 0);

      frame_data_3       : in std_logic_vector(31 downto 0);
      frame_data_valid_3 : in std_logic_vector(3 downto 0);
      meta_data_3        : in std_logic_vector(63 downto 0);
      meta_data_valid_3  : in std_logic_vector(3 downto 0);
      port_data_out_3    : out std_logic_vector(7 downto 0);
      port_data_valid_3  : out std_logic_vector(3 downto 0);
      enough_space_3     : out std_logic_vector(3 downto 0)
    );
  end component crossbar;

  -------------------------------------------------------------------
  -- INTERNAL SIGNALS
  -------------------------------------------------------------------
  -- FCS <-> Data Parking
  signal fcs_out_data  : std_logic_vector(DATA_BUS_WIDTH - 1 downto 0);
  signal fcs_out_valid : std_logic_vector(VALID_BITS - 1 downto 0);
  signal fcs_out_error : std_logic_vector(ERROR_BITS - 1 downto 0);

  -- Data Parking <-> MAC Learning Top
  signal mac_req_valid : std_logic;
  signal mac_dest_mac  : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal mac_src_mac   : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal mac_src_port  : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal mac_ans_ready : std_logic;
  signal mac_dest_port : std_logic_vector(NUM_PORTS - 1 downto 0);

  -- Crossbar Enough Space -> Data Parking Ack
  signal space_ack_0 : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal space_ack_1 : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal space_ack_2 : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal space_ack_3 : std_logic_vector(NUM_PORTS - 1 downto 0);

  -- Data Parking Outputs
  signal dp_p0_data : std_logic_vector(BITS_PER_PORT - 1 downto 0);
  signal dp_p0_len  : std_logic_vector(10 downto 0);
  signal dp_p0_val  : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal dp_p0_req  : std_logic_vector(NUM_PORTS - 1 downto 0);

  signal dp_p1_data : std_logic_vector(BITS_PER_PORT - 1 downto 0);
  signal dp_p1_len  : std_logic_vector(10 downto 0);
  signal dp_p1_val  : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal dp_p1_req  : std_logic_vector(NUM_PORTS - 1 downto 0);

  signal dp_p2_data : std_logic_vector(BITS_PER_PORT - 1 downto 0);
  signal dp_p2_len  : std_logic_vector(10 downto 0);
  signal dp_p2_val  : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal dp_p2_req  : std_logic_vector(NUM_PORTS - 1 downto 0);

  signal dp_p3_data : std_logic_vector(BITS_PER_PORT - 1 downto 0);
  signal dp_p3_len  : std_logic_vector(10 downto 0);
  signal dp_p3_val  : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal dp_p3_req  : std_logic_vector(NUM_PORTS - 1 downto 0);

  -- Crossbar Common Bus Inputs
  signal cb_frame_data_all : std_logic_vector(31 downto 0);
  signal cb_meta_data_all  : std_logic_vector(63 downto 0);
  signal cb_req_meta_valid_op0 : STD_LOGIC_VECTOR(NUM_PORTS - 1 downto 0);
  signal cb_req_meta_valid_op1 : STD_LOGIC_VECTOR(NUM_PORTS - 1 downto 0);
  signal cb_req_meta_valid_op2 : STD_LOGIC_VECTOR(NUM_PORTS - 1 downto 0);
  signal cb_req_meta_valid_op3 : STD_LOGIC_VECTOR(NUM_PORTS - 1 downto 0);
  
  -- Data parking transposed full signal
  signal dp_space_ack_transposed_0 : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal dp_space_ack_transposed_1 : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal dp_space_ack_transposed_2 : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal dp_space_ack_transposed_3 : std_logic_vector(NUM_PORTS - 1 downto 0);

  -- Crossbar Outputs
  signal cb_out_data_0 : std_logic_vector(7 downto 0);
  signal cb_out_val_0  : std_logic_vector(3 downto 0);
  signal cb_out_data_1 : std_logic_vector(7 downto 0);
  signal cb_out_val_1  : std_logic_vector(3 downto 0);
  signal cb_out_data_2 : std_logic_vector(7 downto 0);
  signal cb_out_val_2  : std_logic_vector(3 downto 0);
  signal cb_out_data_3 : std_logic_vector(7 downto 0);
  signal cb_out_val_3  : std_logic_vector(3 downto 0);

begin

  -------------------------------------------------------------------
  -- CONCURRENT ASSIGNMENTS (Routing & Padding)
  -------------------------------------------------------------------
  -- Concatenate frame data (p0 in lower 8 bits, up to p3 in highest 8 bits)
  cb_frame_data_all <= dp_p3_data & dp_p2_data & dp_p1_data & dp_p0_data;

  -- Concatenate meta data with 5-bit '0' padding on the MSB side of each length
  cb_meta_data_all <= ("00000" & dp_p3_len) &
    ("00000" & dp_p2_len) &
    ("00000" & dp_p1_len) &
    ("00000" & dp_p0_len);

  -- Transpose request signals to meta signals
  cb_req_meta_valid_op0 <= dp_p3_req(0) & dp_p2_req(0) & dp_p1_req(0) & dp_p0_req(0);
  cb_req_meta_valid_op1 <= dp_p3_req(1) & dp_p2_req(1) & dp_p1_req(1) & dp_p0_req(1);
  cb_req_meta_valid_op2 <= dp_p3_req(2) & dp_p2_req(2) & dp_p1_req(2) & dp_p0_req(2);
  cb_req_meta_valid_op3 <= dp_p3_req(3) & dp_p2_req(3) & dp_p1_req(3) & dp_p0_req(3);

  -- Transpose enough space signal to fit what is expected by ack signal
  dp_space_ack_transposed_0 <= space_ack_3(0) & space_ack_2(0) & space_ack_1(0) & space_ack_0(0);
  dp_space_ack_transposed_1 <= space_ack_3(1) & space_ack_2(1) & space_ack_1(1) & space_ack_0(1);
  dp_space_ack_transposed_2 <= space_ack_3(2) & space_ack_2(2) & space_ack_1(2) & space_ack_0(2);
  dp_space_ack_transposed_3 <= space_ack_3(3) & space_ack_2(3) & space_ack_1(3) & space_ack_0(3);

  -- Map Crossbar Outputs to Switchcore Transmit Ports
  tx_data(7 downto 0)   <= cb_out_data_0;
  tx_data(15 downto 8)  <= cb_out_data_1;
  tx_data(23 downto 16) <= cb_out_data_2;
  tx_data(31 downto 24) <= cb_out_data_3;

  -- Assuming index 0 of the crossbar's 4-bit valid signal represents the port's active valid state
  tx_ctrl(0) <= cb_out_val_0(0);
  tx_ctrl(1) <= cb_out_val_1(0);
  tx_ctrl(2) <= cb_out_val_2(0);
  tx_ctrl(3) <= cb_out_val_3(0);

  -------------------------------------------------------------------
  -- COMPONENT INSTANTIATIONS
  -------------------------------------------------------------------
  inst_fcs : fcs
  port map
  (
    clk          => clk,
    rst          => reset,
    input_data   => rx_data,
    input_valid  => rx_ctrl,
    output_data  => fcs_out_data,
    output_valid => fcs_out_valid,
    output_error => fcs_out_error
  );

  inst_data_parking : data_parking
  port map
  (
    clk => clk,
    rst => reset,

    input_data  => fcs_out_data,
    input_valid => fcs_out_valid,
    input_error => fcs_out_error,

    ready            => mac_ans_ready,
    dest_port        => mac_dest_port,
    output_valid_mac => mac_req_valid,
    dest_mac         => mac_dest_mac,
    source_mac       => mac_src_mac,
    src_port         => mac_src_port,

    p0_ack => dp_space_ack_transposed_0,
    p1_ack => dp_space_ack_transposed_1,
    p2_ack => dp_space_ack_transposed_2,
    p3_ack => dp_space_ack_transposed_3,

    p0_data          => dp_p0_data,
    p0_packet_length => dp_p0_len,
    p0_request       => dp_p0_req,
    p0_valid         => dp_p0_val,

    p1_data          => dp_p1_data,
    p1_packet_length => dp_p1_len,
    p1_request       => dp_p1_req,
    p1_valid         => dp_p1_val,

    p2_data          => dp_p2_data,
    p2_packet_length => dp_p2_len,
    p2_request       => dp_p2_req,
    p2_valid         => dp_p2_val,

    p3_data          => dp_p3_data,
    p3_packet_length => dp_p3_len,
    p3_request       => dp_p3_req,
    p3_valid         => dp_p3_val
  );

  inst_mac_learning : mac_learning_top
  port map
  (
    clk        => clk,
    rst        => reset,
    valid      => mac_req_valid,
    src_port   => mac_src_port,
    source_mac => mac_src_mac,
    dest_mac   => mac_dest_mac,
    ready      => mac_ans_ready,
    dest_port  => mac_dest_port
  );

  inst_crossbar : crossbar
  port map
  (
    clk => clk,
    rst => reset,

    -- PORT 0 DESTINATION
    frame_data_0       => cb_frame_data_all,
    frame_data_valid_0 => dp_p0_val,
    meta_data_0        => cb_meta_data_all,
    meta_data_valid_0  => cb_req_meta_valid_op0,
    port_data_out_0    => cb_out_data_0,
    port_data_valid_0  => cb_out_val_0,
    enough_space_0     => space_ack_0,

    -- PORT 1 DESTINATION
    frame_data_1       => cb_frame_data_all,
    frame_data_valid_1 => dp_p1_val,
    meta_data_1        => cb_meta_data_all,
    meta_data_valid_1  => cb_req_meta_valid_op1,
    port_data_out_1    => cb_out_data_1,
    port_data_valid_1  => cb_out_val_1,
    enough_space_1     => space_ack_1,

    -- PORT 2 DESTINATION
    frame_data_2       => cb_frame_data_all,
    frame_data_valid_2 => dp_p2_val,
    meta_data_2        => cb_meta_data_all,
    meta_data_valid_2  => cb_req_meta_valid_op2,
    port_data_out_2    => cb_out_data_2,
    port_data_valid_2  => cb_out_val_2,
    enough_space_2     => space_ack_2,

    -- PORT 3 DESTINATION
    frame_data_3       => cb_frame_data_all,
    frame_data_valid_3 => dp_p3_val,
    meta_data_3        => cb_meta_data_all,
    meta_data_valid_3  => cb_req_meta_valid_op3,
    port_data_out_3    => cb_out_data_3,
    port_data_valid_3  => cb_out_val_3,
    enough_space_3     => space_ack_3
  );

end arch;
