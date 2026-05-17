library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity switchcore_multi_tb is
end entity;

architecture tb of switchcore_multi_tb is

    component switchcore is
        port (
            clk       : in std_logic;
            reset     : in std_logic;
            link_sync : in std_logic_vector(3 downto 0);
            tx_data   : out std_logic_vector(31 downto 0);
            tx_ctrl   : out std_logic_vector(3 downto 0);
            rx_data   : in std_logic_vector(31 downto 0);
            rx_ctrl   : in std_logic_vector(3 downto 0)
        );
    end component switchcore;

    constant CLK_PERIOD : time := 10 ns;
    --constant TEST_FILE  : string := "/home/andreas/Documents/Programming/gigabit-ethernet-switch-34349/python/test_vectors/test_standard_transmission.txt";
    constant TEST_FILE  : string := "/home/andreas/Documents/Programming/gigabit-ethernet-switch-34349/python/test_vectors/test_back_to_back.txt";
    --constant TEST_FILE  : string := "/home/andreas/Documents/Programming/gigabit-ethernet-switch-34349/python/test_vectors/test_mac_learning.txt";
    --constant TEST_FILE  : string := "/home/andreas/Documents/Programming/gigabit-ethernet-switch-34349/python/test_vectors/test_errors.txt";
    --constant TEST_FILE  : string := "/home/andreas/Documents/Programming/gigabit-ethernet-switch-34349/python/test_vectors/test_simultaneous_arrival.txt";
    --constant TEST_FILE  : string := "/home/andreas/Documents/Programming/gigabit-ethernet-switch-34349/python/test_vectors/test_multiple_ports.txt";
    --constant TEST_FILE  : string := "/home/andreas/Documents/Programming/gigabit-ethernet-switch-34349/python/test_vectors/test_congestion.txt";
    --constant TEST_FILE  : string := "/home/andreas/Documents/Programming/gigabit-ethernet-switch-34349/python/test_vectors/test_heavy_load.txt";
    --constant TEST_FILE  : string := "/home/andreas/Documents/Programming/gigabit-ethernet-switch-34349/python/test_vectors/test_unique_macs.txt";
    --constant TEST_FILE  : string := "/home/andreas/Documents/Programming/gigabit-ethernet-switch-34349/python/test_vectors/test_fifo_fill_big_packets.txt";
    --constant TEST_FILE  : string := "/home/andreas/Documents/Programming/gigabit-ethernet-switch-34349/python/test_vectors/test_packet_sizes.txt";

    -- Core Signals
    signal clk       : std_logic := '0';
    signal rst       : std_logic := '0'; 
    signal link_sync : std_logic_vector(3 downto 0) := (others => '0');
    signal tx_data   : std_logic_vector(31 downto 0);
    signal tx_ctrl   : std_logic_vector(3 downto 0);
    
    signal port0_rx, port1_rx, port2_rx, port3_rx : std_logic_vector(7 downto 0) := (others => '0');
    signal p0_rx_ctrl, p1_rx_ctrl, p2_rx_ctrl, p3_rx_ctrl : std_logic := '0';
    
    signal rx_data_combined : std_logic_vector(31 downto 0);
    signal rx_ctrl_combined : std_logic_vector(3 downto 0);

    -- Global Simulation State
    signal cycle_count : integer := 0;
    signal parse_done  : boolean := false;
    signal test_done   : boolean := false;

    -- Data Structures
    constant MAX_PKT_LEN : integer := 1536;
    constant MAX_VECTORS : integer := 2000;

    type byte_array_t is array (0 to MAX_PKT_LEN-1) of std_logic_vector(7 downto 0);
    
    type packet_info_t is record
        port_in      : integer;
        start_cycle  : integer;
        expected_out : integer;
        length       : integer;
        data         : byte_array_t;
    end record;

    type packet_array_t is array (0 to MAX_VECTORS-1) of packet_info_t;
    signal test_vectors : packet_array_t;
    signal num_vectors  : integer := 0;

    type expected_fifo_t is array (0 to MAX_VECTORS-1) of integer;
    
    signal exp_fifo_p0, exp_fifo_p1, exp_fifo_p2, exp_fifo_p3 : expected_fifo_t;
    signal exp_count_p0, exp_count_p1, exp_count_p2, exp_count_p3 : integer := 0;
    
    signal exp_idx_p0, exp_idx_p1, exp_idx_p2, exp_idx_p3 : integer := 0;

    -- Function to safely identify valid Hex characters
    function is_hex_char(c : character) return boolean is
    begin
        case c is
            when '0' to '9' | 'a' to 'f' | 'A' to 'F' => return true;
            when others => return false;
        end case;
    end function;

    function hex_to_slv(c : character) return std_logic_vector is
    begin
        case c is
            when '0' => return x"0"; when '1' => return x"1";
            when '2' => return x"2"; when '3' => return x"3";
            when '4' => return x"4"; when '5' => return x"5";
            when '6' => return x"6"; when '7' => return x"7";
            when '8' => return x"8"; when '9' => return x"9";
            when 'a'|'A' => return x"A"; when 'b'|'B' => return x"B";
            when 'c'|'C' => return x"C"; when 'd'|'D' => return x"D";
            when 'e'|'E' => return x"E"; when 'f'|'F' => return x"F";
            when others => return x"0";
        end case;
    end function;

begin

    rx_data_combined <= port3_rx & port2_rx & port1_rx & port0_rx;
    rx_ctrl_combined <= p3_rx_ctrl & p2_rx_ctrl & p1_rx_ctrl & p0_rx_ctrl;

    DUT : switchcore
        port map (
            clk       => clk,
            reset     => rst,
            link_sync => link_sync,
            tx_data   => tx_data,
            tx_ctrl   => tx_ctrl,
            rx_data   => rx_data_combined,
            rx_ctrl   => rx_ctrl_combined
        );

    -- Clock Generation
    clk_gen: process
    begin
        if test_done then wait; end if;
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        cycle_count <= cycle_count + 1;
        wait for CLK_PERIOD / 2;
    end process;

    -- =====================================================================
    -- PARSING PROCESS
    -- =====================================================================
    file_parser : process
        file text_file : text open read_mode is TEST_FILE;
        variable text_line : line;
        variable v_port_in, v_delay, v_expected : integer;
        variable v_char : character;
        variable v_pkt_idx, v_curr_cycle, v_byte_idx : integer := 0;
        variable v_upper, v_lower : std_logic_vector(3 downto 0);
        variable v_exp_cnt_0, v_exp_cnt_1, v_exp_cnt_2, v_exp_cnt_3 : integer := 0;
    begin
        while not endfile(text_file) loop
            readline(text_file, text_line);
            if text_line'length = 0 then next; end if;

            read(text_line, v_port_in);
            read(text_line, v_delay);
            read(text_line, v_expected);

            v_curr_cycle := v_curr_cycle + v_delay;

            test_vectors(v_pkt_idx).port_in <= v_port_in;
            test_vectors(v_pkt_idx).start_cycle <= v_curr_cycle;
            test_vectors(v_pkt_idx).expected_out <= v_expected;

            -- Robust Hex Parsing
            v_byte_idx := 0;
            while text_line'length > 0 loop
                read(text_line, v_char);
                
                if not is_hex_char(v_char) then
                    next;
                end if;
                
                v_upper := hex_to_slv(v_char);
                
                if text_line'length > 0 then
                    read(text_line, v_char);
                    if is_hex_char(v_char) then
                        v_lower := hex_to_slv(v_char);
                    else
                        v_lower := x"0";
                    end if;
                else
                    v_lower := x"0";
                end if;
                
                test_vectors(v_pkt_idx).data(v_byte_idx) <= v_upper & v_lower;
                v_byte_idx := v_byte_idx + 1;
            end loop;

            test_vectors(v_pkt_idx).length <= v_byte_idx;

            if v_expected = 0 or (v_expected = 4 and v_port_in /= 0) then
                exp_fifo_p0(v_exp_cnt_0) <= v_pkt_idx;
                v_exp_cnt_0 := v_exp_cnt_0 + 1;
            end if;
            if v_expected = 1 or (v_expected = 4 and v_port_in /= 1) then
                exp_fifo_p1(v_exp_cnt_1) <= v_pkt_idx;
                v_exp_cnt_1 := v_exp_cnt_1 + 1;
            end if;
            if v_expected = 2 or (v_expected = 4 and v_port_in /= 2) then
                exp_fifo_p2(v_exp_cnt_2) <= v_pkt_idx;
                v_exp_cnt_2 := v_exp_cnt_2 + 1;
            end if;
            if v_expected = 3 or (v_expected = 4 and v_port_in /= 3) then
                exp_fifo_p3(v_exp_cnt_3) <= v_pkt_idx;
                v_exp_cnt_3 := v_exp_cnt_3 + 1;
            end if;

            v_pkt_idx := v_pkt_idx + 1;
        end loop;

        num_vectors <= v_pkt_idx;
        exp_count_p0 <= v_exp_cnt_0;
        exp_count_p1 <= v_exp_cnt_1;
        exp_count_p2 <= v_exp_cnt_2;
        exp_count_p3 <= v_exp_cnt_3;
        
        parse_done <= true;
        wait;
    end process;

    -- Active-Low Reset Process
    process(clk) begin
        if rising_edge(clk) then
            if not parse_done then
                link_sync <= "1111";
                rst <= '0';
            elsif cycle_count = 5 then
                rst <= '1';
                report "=================================================" severity NOTE;
                report "STARTING TO PROVIDE INPUT VECTORS TO SWITCHCORE" severity NOTE;
                report "=================================================" severity NOTE;
            end if;
        end if;
    end process;

    -- =====================================================================
    -- EXPLICIT INJECTOR PROCESSES (WITH IEEE 802.3 12-CYCLE IPG)
    -- =====================================================================
    
    -- Port 0 Injector
    injector_p0: process
    begin
        wait until parse_done and rst = '1';
        for i in 0 to MAX_VECTORS-1 loop
            exit when i = num_vectors;
            if test_vectors(i).port_in = 0 then
                while cycle_count < test_vectors(i).start_cycle + 10 loop wait until rising_edge(clk); end loop;
                for b in 0 to test_vectors(i).length - 1 loop
                    p0_rx_ctrl <= '1'; port0_rx <= test_vectors(i).data(b); wait until rising_edge(clk);
                end loop;
                
                p0_rx_ctrl <= '0'; port0_rx <= (others => '0');
                
                -- ENFORCE MINIMUM 12 CYCLE INTER-FRAME GAP
                for gap in 1 to 12 loop
                    wait until rising_edge(clk);
                end loop;
            end if;
        end loop;
        wait;
    end process;

    -- Port 1 Injector
    injector_p1: process
    begin
        wait until parse_done and rst = '1';
        for i in 0 to MAX_VECTORS-1 loop
            exit when i = num_vectors;
            if test_vectors(i).port_in = 1 then
                while cycle_count < test_vectors(i).start_cycle + 10 loop wait until rising_edge(clk); end loop;
                for b in 0 to test_vectors(i).length - 1 loop
                    p1_rx_ctrl <= '1'; port1_rx <= test_vectors(i).data(b); wait until rising_edge(clk);
                end loop;
                
                p1_rx_ctrl <= '0'; port1_rx <= (others => '0');
                
                -- ENFORCE MINIMUM 12 CYCLE INTER-FRAME GAP
                for gap in 1 to 12 loop
                    wait until rising_edge(clk);
                end loop;
            end if;
        end loop;
        wait;
    end process;

    -- Port 2 Injector
    injector_p2: process
    begin
        wait until parse_done and rst = '1';
        for i in 0 to MAX_VECTORS-1 loop
            exit when i = num_vectors;
            if test_vectors(i).port_in = 2 then
                while cycle_count < test_vectors(i).start_cycle + 10 loop wait until rising_edge(clk); end loop;
                for b in 0 to test_vectors(i).length - 1 loop
                    p2_rx_ctrl <= '1'; port2_rx <= test_vectors(i).data(b); wait until rising_edge(clk);
                end loop;
                
                p2_rx_ctrl <= '0'; port2_rx <= (others => '0');
                
                -- ENFORCE MINIMUM 12 CYCLE INTER-FRAME GAP
                for gap in 1 to 12 loop
                    wait until rising_edge(clk);
                end loop;
            end if;
        end loop;
        wait;
    end process;

    -- Port 3 Injector
    injector_p3: process
    begin
        wait until parse_done and rst = '1';
        for i in 0 to MAX_VECTORS-1 loop
            exit when i = num_vectors;
            if test_vectors(i).port_in = 3 then
                while cycle_count < test_vectors(i).start_cycle + 10 loop wait until rising_edge(clk); end loop;
                for b in 0 to test_vectors(i).length - 1 loop
                    p3_rx_ctrl <= '1'; port3_rx <= test_vectors(i).data(b); wait until rising_edge(clk);
                end loop;
                
                p3_rx_ctrl <= '0'; port3_rx <= (others => '0');
                
                -- ENFORCE MINIMUM 12 CYCLE INTER-FRAME GAP
                for gap in 1 to 12 loop
                    wait until rising_edge(clk);
                end loop;
            end if;
        end loop;
        wait;
    end process;


    -- =====================================================================
    -- EXPLICIT CHECKER PROCESSES
    -- =====================================================================
    
    -- Port 0 Checker
    checker_p0: process
        variable v_byte_idx, v_pkt_ref : integer := 0;
        variable v_rx_byte : std_logic_vector(7 downto 0);
    begin
        wait until parse_done and rst = '1';
        loop
            wait until rising_edge(clk);
            if tx_ctrl(0) = '1' then
                if exp_idx_p0 < exp_count_p0 then
                    v_pkt_ref := exp_fifo_p0(exp_idx_p0);
                    v_rx_byte := tx_data(7 downto 0);

                    if v_rx_byte /= test_vectors(v_pkt_ref).data(v_byte_idx) then
                        report "MALFORMED PACKET on Port 0 Byte index " & integer'image(v_byte_idx) severity ERROR;
                    end if;

                    v_byte_idx := v_byte_idx + 1;
                    if v_byte_idx = test_vectors(v_pkt_ref).length then
                        v_byte_idx := 0; exp_idx_p0 <= exp_idx_p0 + 1;
                    end if;
                else
                    report "WARNING: Unexpected packet on Port 0 (Expected=5)" severity WARNING;
                end if;
            else
                if v_byte_idx > 0 then
                    report "PACKET TRUNCATED on Port 0" severity ERROR;
                    v_byte_idx := 0; exp_idx_p0 <= exp_idx_p0 + 1;
                end if;
            end if;
        end loop;
    end process;

    -- Port 1 Checker
    checker_p1: process
        variable v_byte_idx, v_pkt_ref : integer := 0;
        variable v_rx_byte : std_logic_vector(7 downto 0);
    begin
        wait until parse_done and rst = '1';
        loop
            wait until rising_edge(clk);
            if tx_ctrl(1) = '1' then
                if exp_idx_p1 < exp_count_p1 then
                    v_pkt_ref := exp_fifo_p1(exp_idx_p1);
                    v_rx_byte := tx_data(15 downto 8);

                    if v_rx_byte /= test_vectors(v_pkt_ref).data(v_byte_idx) then
                        report "MALFORMED PACKET on Port 1 Byte index " & integer'image(v_byte_idx) severity ERROR;
                    end if;

                    v_byte_idx := v_byte_idx + 1;
                    if v_byte_idx = test_vectors(v_pkt_ref).length then
                        v_byte_idx := 0; exp_idx_p1 <= exp_idx_p1 + 1;
                    end if;
                else
                    report "WARNING: Unexpected packet on Port 1 (Expected=5)" severity WARNING;
                end if;
            else
                if v_byte_idx > 0 then
                    report "PACKET TRUNCATED on Port 1" severity ERROR;
                    v_byte_idx := 0; exp_idx_p1 <= exp_idx_p1 + 1;
                end if;
            end if;
        end loop;
    end process;

    -- Port 2 Checker
    checker_p2: process
        variable v_byte_idx, v_pkt_ref : integer := 0;
        variable v_rx_byte : std_logic_vector(7 downto 0);
    begin
        wait until parse_done and rst = '1';
        loop
            wait until rising_edge(clk);
            if tx_ctrl(2) = '1' then
                if exp_idx_p2 < exp_count_p2 then
                    v_pkt_ref := exp_fifo_p2(exp_idx_p2);
                    v_rx_byte := tx_data(23 downto 16);

                    if v_rx_byte /= test_vectors(v_pkt_ref).data(v_byte_idx) then
                        report "MALFORMED PACKET on Port 2 Byte index " & integer'image(v_byte_idx) severity ERROR;
                    end if;

                    v_byte_idx := v_byte_idx + 1;
                    if v_byte_idx = test_vectors(v_pkt_ref).length then
                        v_byte_idx := 0; exp_idx_p2 <= exp_idx_p2 + 1;
                    end if;
                else
                    report "WARNING: Unexpected packet on Port 2 (Expected=5)" severity WARNING;
                end if;
            else
                if v_byte_idx > 0 then
                    report "PACKET TRUNCATED on Port 2" severity ERROR;
                    v_byte_idx := 0; exp_idx_p2 <= exp_idx_p2 + 1;
                end if;
            end if;
        end loop;
    end process;

    -- Port 3 Checker
    checker_p3: process
        variable v_byte_idx, v_pkt_ref : integer := 0;
        variable v_rx_byte : std_logic_vector(7 downto 0);
    begin
        wait until parse_done and rst = '1';
        loop
            wait until rising_edge(clk);
            if tx_ctrl(3) = '1' then
                if exp_idx_p3 < exp_count_p3 then
                    v_pkt_ref := exp_fifo_p3(exp_idx_p3);
                    v_rx_byte := tx_data(31 downto 24);

                    if v_rx_byte /= test_vectors(v_pkt_ref).data(v_byte_idx) then
                        report "MALFORMED PACKET on Port 3 Byte index " & integer'image(v_byte_idx) severity ERROR;
                    end if;

                    v_byte_idx := v_byte_idx + 1;
                    if v_byte_idx = test_vectors(v_pkt_ref).length then
                        v_byte_idx := 0; exp_idx_p3 <= exp_idx_p3 + 1;
                    end if;
                else
                    report "WARNING: Unexpected packet on Port 3 (Expected=5)" severity WARNING;
                end if;
            else
                if v_byte_idx > 0 then
                    report "PACKET TRUNCATED on Port 3" severity ERROR;
                    v_byte_idx := 0; exp_idx_p3 <= exp_idx_p3 + 1;
                end if;
            end if;
        end loop;
    end process;


    -- =====================================================================
    -- COMPLETION MONITOR
    -- =====================================================================
    process
    begin
        wait until parse_done and rst = '1';
        
        loop
            wait until rising_edge(clk);
            if (exp_idx_p0 = exp_count_p0 and exp_idx_p1 = exp_count_p1 and 
                exp_idx_p2 = exp_count_p2 and exp_idx_p3 = exp_count_p3) then
                
                wait for CLK_PERIOD * 50; 
                
                report "=================================================" severity NOTE;
                report "TEST VECTOR SUCCESSFULLY RAN WITHOUT ERRORS" severity NOTE;
                report "ALL TESTS COMPLETED" severity NOTE;
                report "=================================================" severity NOTE;
                
                test_done <= true;
                wait;
            end if;
        end loop;
    end process;

end architecture;