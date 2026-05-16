library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use std.textio.all;

use work.constants.all;

entity fcs_check_parallel_tb is
end entity;

architecture sim of fcs_check_parallel_tb is

	-- Input
	signal clk_tb       : std_logic := '0';
	signal reset_tb     : std_logic := '1'; -- Active-low reset
	signal input_data   : std_logic_vector(DATA_BUS_WIDTH - 1 downto 0) := x"00000000";
	signal input_valid  : std_logic_vector(VALID_BITS - 1 downto 0) := "0000";
	
	-- Output
	signal output_data  : std_logic_vector(DATA_BUS_WIDTH - 1 downto 0) := x"00000000";
	signal output_valid : std_logic_vector(VALID_BITS - 1 downto 0) := "0000";
	signal output_error : std_logic_vector(ERROR_BITS - 1 downto 0) := "0000";
	
	-- Test ip-packet
	constant DATA            : std_logic_vector(575 downto 0) := x"55555555555555D50010A47BEA8000123456789008004500002EB3FE000080110540C0A8002CC0A8000404000400001A2DE8000102030405060708090A0B0C0D0E0F1011E6C53DB2";
	constant DATA_WITH_ERROR : std_logic_vector(575 downto 0) := x"55555555555555D50010A47BEA8000123456789008004500002EB3FE010080110540C0A8002CC0A8000404000400001A2DE8000102030405060708090A0B0C0D0E0F1011E6C53DB2";
	constant CLK_PERIOD      : time                           := 20 ns;

	-- Test status signal
	type test_state_t is (ALL_VALID, ALL_INVALID, VALID_01, VALID_23);
	signal test_state : test_state_t := ALL_VALID;
	
begin

	DUT: entity work.fcs
		port map(
			clk          => clk_tb,
			rst          => reset_tb,
			input_data   => input_data,
			input_valid  => input_valid,
			output_data  => output_data,
			output_valid => output_valid,
			output_error => output_error
		);
	
	clk_process: process
	begin
		while true loop
			clk_tb <= '0';
			wait for CLK_PERIOD/2;
			clk_tb <= '1';
			wait for CLK_PERIOD/2;
		end loop;
	end process;
	
	test_process: process
	begin
		reset_tb <= '0';
		wait for 50 ns;
		reset_tb <= '1';
		wait for 20 ns;
		
		-- Valid on all ports, 4 packets back to back
		test_state <= ALL_VALID;
		for j in 0 to 3 loop
			for i in 71 downto 0 loop
				input_valid <= "1111";

				-- Port 0
				input_data(0) <= DATA(i*8+0);
				input_data(1) <= DATA(i*8+1);
				input_data(2) <= DATA(i*8+2);
				input_data(3) <= DATA(i*8+3);
				input_data(4) <= DATA(i*8+4);
				input_data(5) <= DATA(i*8+5);
				input_data(6) <= DATA(i*8+6);
				input_data(7) <= DATA(i*8+7);
	
				-- Port 1
				input_data(8)  <= DATA(i*8+0);
				input_data(9)  <= DATA(i*8+1);
				input_data(10) <= DATA(i*8+2);
				input_data(11) <= DATA(i*8+3);
				input_data(12) <= DATA(i*8+4);
				input_data(13) <= DATA(i*8+5);
				input_data(14) <= DATA(i*8+6);
				input_data(15) <= DATA(i*8+7);

				-- Port 2
				input_data(16) <= DATA(i*8+0);
				input_data(17) <= DATA(i*8+1);
				input_data(18) <= DATA(i*8+2);
				input_data(19) <= DATA(i*8+3);
				input_data(20) <= DATA(i*8+4);
				input_data(21) <= DATA(i*8+5);
				input_data(22) <= DATA(i*8+6);
				input_data(23) <= DATA(i*8+7);

				-- Port 3
				input_data(24) <= DATA(i*8+0);
				input_data(25) <= DATA(i*8+1);
				input_data(26) <= DATA(i*8+2);
				input_data(27) <= DATA(i*8+3);
				input_data(28) <= DATA(i*8+4);
				input_data(29) <= DATA(i*8+5);
				input_data(30) <= DATA(i*8+6);
				input_data(31) <= DATA(i*8+7);
				wait for CLK_PERIOD;
			end loop;
			
			input_valid <= "0000";
			input_data <= x"00000000";
			wait for CLK_PERIOD * 12; -- interpacket gap
		end loop;

		-- Invalid on all ports, 4 packets back to back
		test_state <= ALL_INVALID;
		for j in 0 to 3 loop
			for i in 71 downto 0 loop
				input_valid <= "1111";

				-- Port 0
				input_data(0) <= DATA_WITH_ERROR(i*8+0);
				input_data(1) <= DATA_WITH_ERROR(i*8+1);
				input_data(2) <= DATA_WITH_ERROR(i*8+2);
				input_data(3) <= DATA_WITH_ERROR(i*8+3);
				input_data(4) <= DATA_WITH_ERROR(i*8+4);
				input_data(5) <= DATA_WITH_ERROR(i*8+5);
				input_data(6) <= DATA_WITH_ERROR(i*8+6);
				input_data(7) <= DATA_WITH_ERROR(i*8+7);
	
				-- Port 1
				input_data(8)  <= DATA_WITH_ERROR(i*8+0);
				input_data(9)  <= DATA_WITH_ERROR(i*8+1);
				input_data(10) <= DATA_WITH_ERROR(i*8+2);
				input_data(11) <= DATA_WITH_ERROR(i*8+3);
				input_data(12) <= DATA_WITH_ERROR(i*8+4);
				input_data(13) <= DATA_WITH_ERROR(i*8+5);
				input_data(14) <= DATA_WITH_ERROR(i*8+6);
				input_data(15) <= DATA_WITH_ERROR(i*8+7);

				-- Port 2
				input_data(16) <= DATA_WITH_ERROR(i*8+0);
				input_data(17) <= DATA_WITH_ERROR(i*8+1);
				input_data(18) <= DATA_WITH_ERROR(i*8+2);
				input_data(19) <= DATA_WITH_ERROR(i*8+3);
				input_data(20) <= DATA_WITH_ERROR(i*8+4);
				input_data(21) <= DATA_WITH_ERROR(i*8+5);
				input_data(22) <= DATA_WITH_ERROR(i*8+6);
				input_data(23) <= DATA_WITH_ERROR(i*8+7);

				-- Port 3
				input_data(24) <= DATA_WITH_ERROR(i*8+0);
				input_data(25) <= DATA_WITH_ERROR(i*8+1);
				input_data(26) <= DATA_WITH_ERROR(i*8+2);
				input_data(27) <= DATA_WITH_ERROR(i*8+3);
				input_data(28) <= DATA_WITH_ERROR(i*8+4);
				input_data(29) <= DATA_WITH_ERROR(i*8+5);
				input_data(30) <= DATA_WITH_ERROR(i*8+6);
				input_data(31) <= DATA_WITH_ERROR(i*8+7);
				wait for CLK_PERIOD;
			end loop;
			
			input_valid <= "0000";
			input_data <= x"00000000";
			wait for CLK_PERIOD * 12; -- interpacket gap
		end loop;

		-- Valid on port 0 and 1, invalid on port 2 and 3, 4 packets back to back
		test_state <= VALID_01;
		for j in 0 to 3 loop
			for i in 71 downto 0 loop
				input_valid <= "1111";

				-- Port 0
				input_data(0) <= DATA(i*8+0);
				input_data(1) <= DATA(i*8+1);
				input_data(2) <= DATA(i*8+2);
				input_data(3) <= DATA(i*8+3);
				input_data(4) <= DATA(i*8+4);
				input_data(5) <= DATA(i*8+5);
				input_data(6) <= DATA(i*8+6);
				input_data(7) <= DATA(i*8+7);
	
				-- Port 1
				input_data(8)  <= DATA(i*8+0);
				input_data(9)  <= DATA(i*8+1);
				input_data(10) <= DATA(i*8+2);
				input_data(11) <= DATA(i*8+3);
				input_data(12) <= DATA(i*8+4);
				input_data(13) <= DATA(i*8+5);
				input_data(14) <= DATA(i*8+6);
				input_data(15) <= DATA(i*8+7);

				-- Port 2
				input_data(16) <= DATA_WITH_ERROR(i*8+0);
				input_data(17) <= DATA_WITH_ERROR(i*8+1);
				input_data(18) <= DATA_WITH_ERROR(i*8+2);
				input_data(19) <= DATA_WITH_ERROR(i*8+3);
				input_data(20) <= DATA_WITH_ERROR(i*8+4);
				input_data(21) <= DATA_WITH_ERROR(i*8+5);
				input_data(22) <= DATA_WITH_ERROR(i*8+6);
				input_data(23) <= DATA_WITH_ERROR(i*8+7);

				-- Port 3
				input_data(24) <= DATA_WITH_ERROR(i*8+0);
				input_data(25) <= DATA_WITH_ERROR(i*8+1);
				input_data(26) <= DATA_WITH_ERROR(i*8+2);
				input_data(27) <= DATA_WITH_ERROR(i*8+3);
				input_data(28) <= DATA_WITH_ERROR(i*8+4);
				input_data(29) <= DATA_WITH_ERROR(i*8+5);
				input_data(30) <= DATA_WITH_ERROR(i*8+6);
				input_data(31) <= DATA_WITH_ERROR(i*8+7);
				wait for CLK_PERIOD;
			end loop;
			
			input_valid <= "0000";
			input_data <= x"00000000";
			wait for CLK_PERIOD * 12; -- interpacket gap
		end loop;

		-- Invalid on port 0 and 1, valid on port 2 and 3, 4 packets back to back
		test_state <= VALID_23;
		for j in 0 to 3 loop
			for i in 71 downto 0 loop
				input_valid <= "1111";

				-- Port 0
				input_data(0) <= DATA_WITH_ERROR(i*8+0);
				input_data(1) <= DATA_WITH_ERROR(i*8+1);
				input_data(2) <= DATA_WITH_ERROR(i*8+2);
				input_data(3) <= DATA_WITH_ERROR(i*8+3);
				input_data(4) <= DATA_WITH_ERROR(i*8+4);
				input_data(5) <= DATA_WITH_ERROR(i*8+5);
				input_data(6) <= DATA_WITH_ERROR(i*8+6);
				input_data(7) <= DATA_WITH_ERROR(i*8+7);
	
				-- Port 1
				input_data(8)  <= DATA_WITH_ERROR(i*8+0);
				input_data(9)  <= DATA_WITH_ERROR(i*8+1);
				input_data(10) <= DATA_WITH_ERROR(i*8+2);
				input_data(11) <= DATA_WITH_ERROR(i*8+3);
				input_data(12) <= DATA_WITH_ERROR(i*8+4);
				input_data(13) <= DATA_WITH_ERROR(i*8+5);
				input_data(14) <= DATA_WITH_ERROR(i*8+6);
				input_data(15) <= DATA_WITH_ERROR(i*8+7);

				-- Port 2
				input_data(16) <= DATA(i*8+0);
				input_data(17) <= DATA(i*8+1);
				input_data(18) <= DATA(i*8+2);
				input_data(19) <= DATA(i*8+3);
				input_data(20) <= DATA(i*8+4);
				input_data(21) <= DATA(i*8+5);
				input_data(22) <= DATA(i*8+6);
				input_data(23) <= DATA(i*8+7);

				-- Port 3
				input_data(24) <= DATA(i*8+0);
				input_data(25) <= DATA(i*8+1);
				input_data(26) <= DATA(i*8+2);
				input_data(27) <= DATA(i*8+3);
				input_data(28) <= DATA(i*8+4);
				input_data(29) <= DATA(i*8+5);
				input_data(30) <= DATA(i*8+6);
				input_data(31) <= DATA(i*8+7);
				wait for CLK_PERIOD;
			end loop;
			
			input_valid <= "0000";
			input_data <= x"00000000";
			wait for CLK_PERIOD * 12; -- interpacket gap
		end loop;


		
		-- Stop test so it doesn't run forever
		 assert false
			  report "Simulation Finished Successfully"
			  severity failure;
		
	end process;
	
end architecture;