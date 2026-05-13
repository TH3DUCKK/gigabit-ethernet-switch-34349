library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.constants.all;

entity switchcore_tb is
end entity switchcore_tb;

architecture tb of switchcore_tb is

  -- Component declaration
  component switchcore is
    port (
      -- Clock and reset
      clk : in std_logic;
      reset : in std_logic;

      -- Activity indicators
      link_sync : in std_logic_vector(3 downto 0); -- High indicates a peer connection at the physical layer.

      -- Four GMII interfaces
      tx_data : out std_logic_vector(31 downto 0); -- (7 downto 0)=TXD0...(31 downto 24=TXD3)
      tx_ctrl : out std_logic_vector(3 downto 0); -- (0)=TXC0...(3=TXC3)
      rx_data : in std_logic_vector(31 downto 0); -- (7 downto 0)=RXD0...(31 downto 24=RXD3)
      rx_ctrl : in std_logic_vector(3 downto 0)  -- (0)=RXC0...(3=RXC3)
    );
  end component switchcore;

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

-- Test Selection (Change this to run different tests)
  constant G_TEST_FILE : string := "test_vectors/test_standard_transmission.txt";

  -- ==========================================
  -- Sequencer / Driver Communication Signals
  -- ==========================================
  constant MAX_PKT_SIZE : integer := 1530;
  type pkt_buffer_t is array(0 to MAX_PKT_SIZE-1) of std_logic_vector(7 downto 0);
  type buffer_arr_t is array(0 to 3) of pkt_buffer_t;
  type len_arr_t    is array(0 to 3) of integer;
  type rx_data_arr_t is array(0 to 3) of std_logic_vector(7 downto 0);

  signal tb_pkt_buf  : buffer_arr_t;
  signal tb_pkt_len  : len_arr_t := (others => 0);
  signal tb_req      : std_logic_vector(3 downto 0) := (others => '0');
  signal tb_ack      : std_logic_vector(3 downto 0) := (others => '0');
  signal rx_data_arr : rx_data_arr_t := (others => (others => '0'));

  -- ==========================================
  -- Helper Function: Hex Character to Std Logic Vector
  -- ==========================================
  function char_to_slv(c : character) return std_logic_vector is
      variable v_slv : std_logic_vector(3 downto 0);
  begin
      case c is
          when '0' => v_slv := x"0"; when '1' => v_slv := x"1";
          when '2' => v_slv := x"2"; when '3' => v_slv := x"3";
          when '4' => v_slv := x"4"; when '5' => v_slv := x"5";
          when '6' => v_slv := x"6"; when '7' => v_slv := x"7";
          when '8' => v_slv := x"8"; when '9' => v_slv := x"9";
          when 'a' | 'A' => v_slv := x"A"; when 'b' | 'B' => v_slv := x"B";
          when 'c' | 'C' => v_slv := x"C"; when 'd' | 'D' => v_slv := x"D";
          when 'e' | 'E' => v_slv := x"E"; when 'f' | 'F' => v_slv := x"F";
          when others => v_slv := x"0";
      end case;
      return v_slv;
  end function;

begin

  -- Map array to your specific signals for the DUT instantiation
  port0_rx <= rx_data_arr(0);
  port1_rx <= rx_data_arr(1);
  port2_rx <= rx_data_arr(2);
  port3_rx <= rx_data_arr(3);

  dut : switchcore
    port map (
      clk       => clk,
      reset       => rst,
      link_sync => link_sync,
      -- Note on concatenation: port0_tx & port1_tx means port0 is in bits 31 downto 24
      tx_data   => port3_tx & port2_tx & port1_tx & port0_tx,
      tx_ctrl   => tx_ctrl,
      rx_data   => port3_rx & port2_rx & port1_rx & port0_rx,
      rx_ctrl   => rx_ctrl
    );

  -- Clock generation
  clk <= not clk after CLK_PERIOD / 2;

  -- ==========================================
  -- Main Sequencer (Replaces your test_process)
  -- ==========================================
  p_sequencer : process
      file f_test_file     : text open read_mode is G_TEST_FILE;
      variable v_line      : line;
      variable v_port      : integer;
      variable v_delay     : integer;
      variable v_space     : character;
      variable v_hex_char1 : character;
      variable v_hex_char2 : character;
      variable v_byte_count: integer;
      variable v_good      : boolean;
  begin
      -- 1. Initialize Switch
      link_sync <= "0000";
      rst <= '1';
      wait for CLK_PERIOD * 2;
      rst <= '0';
      wait for CLK_PERIOD;
      
      -- Set Links to UP
      link_sync <= "1111"; 
      wait for CLK_PERIOD * 10;

      -- 2. Read File Loop
      while not endfile(f_test_file) loop
          readline(f_test_file, v_line);
          if v_line'length = 0 then next; end if; 

          read(v_line, v_port);
          read(v_line, v_space);
          read(v_line, v_delay);
          read(v_line, v_space);

          -- Wait for specified delay cycles
          if v_delay > 0 then
              for i in 1 to v_delay loop
                  wait until rising_edge(clk);
              end loop;
          end if;

          -- Check if target port is busy
          if tb_req(v_port) /= tb_ack(v_port) then
              wait until tb_req(v_port) = tb_ack(v_port);
          end if;

          -- Parse Hex Data
          v_byte_count := 0;
          while v_line'length > 0 loop
              read(v_line, v_hex_char1, v_good);
              exit when not v_good or v_hex_char1 = ' ' or v_hex_char1 = CR or v_hex_char1 = LF;
              read(v_line, v_hex_char2, v_good);

              tb_pkt_buf(v_port)(v_byte_count) <= char_to_slv(v_hex_char1) & char_to_slv(v_hex_char2);
              v_byte_count := v_byte_count + 1;
          end loop;

          -- Dispatch packet to the port driver
          tb_pkt_len(v_port) <= v_byte_count;
          tb_req(v_port) <= not tb_req(v_port); 

      end loop;

      report "========== END OF TEST VECTORS ==========" severity note;
      wait;
  end process;

  -- ==========================================
  -- GMII Port Drivers (4 Independent Processes)
  -- ==========================================
  gen_port_drivers: for p in 0 to 3 generate
      p_port_tx: process
          variable v_ack : std_logic := '0';
      begin
          -- 1. Wait for request from sequencer
          wait until tb_req(p) /= v_ack; 
          
          -- 2. Optional: If your MAC expects an Ethernet Preamble/SFD, you can insert it here.
          -- For example: 7 bytes of x"55", 1 byte of x"D5"
          
          -- 3. Drive GMII data and control
          for i in 0 to tb_pkt_len(p)-1 loop
              rx_data_arr(p) <= tb_pkt_buf(p)(i);
              rx_ctrl(p)     <= '1'; -- GMII RX_DV is high when data is valid
              wait until rising_edge(clk);
          end loop;

          -- 4. Idle interface
          rx_data_arr(p) <= (others => '0');
          rx_ctrl(p)     <= '0';

          -- 5. Acknowledge back to sequencer
          v_ack := not v_ack;
          tb_ack(p) <= v_ack;
          
      end process;
  end generate;

end architecture;