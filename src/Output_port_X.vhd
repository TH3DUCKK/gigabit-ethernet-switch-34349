LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.constants.all;

entity Output_port_X is 
	port (
		clk 		: in std_logic; 	
		rst 		: in std_logic; 
		frame_data 	: in std_logic_vector(31 downto 0); 
		frame_data_valid : in std_logic_vector(3 downto 0); 
		meta_data	: in std_logic_vector(63 downto 0); 
		meta_data_valid : in std_logic_vector(3 downto 0); 
		
		port_data_out 	: out std_logic_vector(7 downto 0); 
		port_data_valid : out std_logic_vector(3 downto 0); 
		enough_space	: out std_logic_vector(3 downto 0)
	); 

end entity Output_port_X; 

architecture rtl of Output_port_X is

	-- internal signals
	signal empty_int 	: std_logic_vector(NUM_PORTS - 1 downto 0):= "1111"; 
	signal frame_done_int	: std_logic_vector(NUM_PORTS - 1 downto 0) := "0000"; 
	signal read_en_int 	: std_logic_vector(NUM_PORTS -1 downto 0) := "0000"; 
	signal sel_int 		: std_logic_vector(3 downto 0) := "0000"; 

	signal port_data_out_int 	: std_logic_vector(31 downto 0); 
	signal port_data_out_mux 	: std_logic_vector(7 downto 0); 

	--signal frmae_data_int 	: std_logic_vector(23 downto 0); 
	--signal frame_data_valid  : std_logic_vector(3 downto 0); 
	
	-- components 

	component crossbar_double_fifo is 
		port(
			clk		: in std_logic; 
			rst		: in std_logic; 
			frame_data	: in std_logic_vector(7 downto 0); 
			frame_data_valid : in std_logic; 
			meta_data	: in std_logic_vector(15 downto 0); 
			meta_data_valid	: in std_logic; 
			port_data_out	: out std_logic_vector( 7 downto 0); 
			port_data_valid	: out std_logic;
			enough_space	: out std_logic;
			end_of_frame 	: out std_logic; 
			empty_frame_fifo : out std_logic;  
			RR_read_enable : in std_logic		); 
	end component crossbar_double_fifo; 

	component Round_Robin is 
		port( 
			clock 		: in std_logic; 
			reset 		: in std_logic; 

			empty 		: in std_logic_vector(NUM_PORTS - 1 downto 0); -- empty signal from fifos
			frame_done 	: in std_logic_vector(NUM_PORTS - 1 downto 0); -- end of frame
			read_en 	: out std_logic_vector(NUM_PORTS - 1 downto 0);
			
			sel 		: out std_logic_vector(NUM_PORTS - 1 downto 0)
		); 
	end component Round_Robin;




begin

	crossbar_double_fifo_inst_0 : crossbar_double_fifo
		port map(
			clk		=> clk, 
			rst		=> rst,
			frame_data	=> frame_data(7 downto 0),
			frame_data_valid => frame_data_valid(0),
			meta_data	=> meta_data(15 downto 0),
			meta_data_valid	=> meta_data_valid(0),
			port_data_out	=> port_data_out_int(7 downto 0),
			port_data_valid	=> port_data_valid(0),
			enough_space => enough_space(0),
			end_of_frame => frame_done_int(0),
			empty_frame_fifo => empty_int(0), 
			RR_read_enable => read_en_int(0)
		); 

	crossbar_double_fifo_inst_1 : crossbar_double_fifo
		port map(
			clk		=> clk, 
			rst		=> rst,
			frame_data	=> frame_data(15 downto 8),
			frame_data_valid => frame_data_valid(1),
			meta_data	=> meta_data(47 downto 32),
			meta_data_valid	=> meta_data_valid(1),
			port_data_out	=> port_data_out_int(15 downto 8),
			port_data_valid	=> port_data_valid(1),
			enough_space => enough_space(1),
			end_of_frame => frame_done_int(1),
			empty_frame_fifo => empty_int(1), 
			RR_read_enable => read_en_int(1)
		);

	crossbar_double_fifo_inst_2 : crossbar_double_fifo
		port map(
			clk		=> clk, 
			rst		=> rst,
			frame_data	=> frame_data(23 downto 16),
			frame_data_valid => frame_data_valid(2),
			meta_data	=> meta_data(47 downto 32),
			meta_data_valid	=> meta_data_valid(2),
			port_data_out	=> port_data_out_int(23 downto 16),
			port_data_valid	=> port_data_valid(2),
			enough_space => enough_space(2),
			end_of_frame => frame_done_int(2),
			empty_frame_fifo => empty_int(2), 
			RR_read_enable => read_en_int(2)
		);
	
	crossbar_double_fifo_inst_3 : crossbar_double_fifo
		port map(
			clk		=> clk, 
			rst		=> rst,
			frame_data	=> frame_data(31 downto 24),
			frame_data_valid => frame_data_valid(3),
			meta_data	=> meta_data(63 downto 48),
			meta_data_valid	=> meta_data_valid(3),
			port_data_out	=> port_data_out_int(31 downto 24),
			port_data_valid	=> port_data_valid(3),
			enough_space => enough_space(3),
			end_of_frame => frame_done_int(3),
			empty_frame_fifo => empty_int(3), 
			RR_read_enable => read_en_int(3)
		);
	

	Round_Robin_inst : Round_Robin
		port map(
			clock => clk, 
			reset => rst, 
			empty => empty_int,
			frame_done => frame_done_int,
			read_en => read_en_int,
			sel => sel_int
		); 
	
	port_Mux : process (sel_int, port_data_out_mux, port_data_out_int)
	begin 
		case sel_int is 
			when "0001" => port_data_out_mux <= port_data_out_int(7 downto 0); 
			when "0010" => port_data_out_mux <= port_data_out_int(15 downto 8); 
			when "0100" => port_data_out_mux <= port_data_out_int(23 downto 16);
			when "1000" => port_data_out_mux <= port_data_out_int(31 downto 24);
			when others => port_data_out_mux <= x"00"; 
		end case; 
	end process port_Mux; 

	port_data_out <= port_data_out_mux;

end architecture; 
