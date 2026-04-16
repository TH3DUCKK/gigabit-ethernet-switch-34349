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
			wait for 10 ns;
			clk_tb <= '1';
			wait for 10 ns;
		end loop;
	end process;
	
	test_process: process
	begin
		reset_tb <= '0';
		wait for 50 ns;
		reset_tb <= '1';
		wait for 20 ns;
		
		
		for i in 71 downto 0 loop
			input_valid <= "0011";
			input_data(0) <= DATA(i*8+0);
			input_data(1) <= DATA(i*8+1);
			input_data(2) <= DATA(i*8+2);
			input_data(3) <= DATA(i*8+3);
			input_data(4) <= DATA(i*8+4);
			input_data(5) <= DATA(i*8+5);
			input_data(6) <= DATA(i*8+6);
			input_data(7) <= DATA(i*8+7);

			input_data(8)  <= DATA_WITH_ERROR(i*8+0);
			input_data(9)  <= DATA_WITH_ERROR(i*8+1);
			input_data(10) <= DATA_WITH_ERROR(i*8+2);
			input_data(11) <= DATA_WITH_ERROR(i*8+3);
			input_data(12) <= DATA_WITH_ERROR(i*8+4);
			input_data(13) <= DATA_WITH_ERROR(i*8+5);
			input_data(14) <= DATA_WITH_ERROR(i*8+6);
			input_data(15) <= DATA_WITH_ERROR(i*8+7);
			
			input_data(31 downto 16) <= x"0000";
			wait for 20 ns;
		end loop;
		
		input_valid <= "0000";
		input_data <= x"00000000";
		wait for 80 ns;
		
		-- Stop test so it doesn't run forever
		 assert false
			  report "Simulation Finished Successfully"
			  severity failure;
		
	end process;
	
end architecture;