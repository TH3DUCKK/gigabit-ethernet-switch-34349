library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

entity crossbar is
  	port (
    		-- Clock and reset
    		clk : in std_logic;
    		rst : in std_logic;
    		-- Data inputs

    		-- input_data  : in std_logic_vector(DATA_BUS_WIDTH - 1 downto 0);
		input_data  : in std_logic_vector(7 downto 0);

    		--input_valid : in std_logic_vector(VALID_BITS - 1 downto 0);
		input_valid : in std_logic;

    		-- Data outputs
    		--output_data  : out std_logic_vector(DATA_BUS_WIDTH - 1 downto 0);
		output_data  : out std_logic_vector(7 downto 0);

    		--output_valid : out std_logic_vector(VALID_BITS - 1 downto 0);
		output_valid : out std_logic;
    		-- Mac inputs
    		dest_port : in std_logic_vector(NUM_PORTS - 1 downto 0) -- One bit per port
  		);
end entity crossbar;

architecture rtl of crossbar is 


	signal output_sel : std_logic_vector(3 downto 0);
	signal read_fifo  : std_logic; 
	signal empty_con  : std_logic; 
	
	component fifo_mem
		
	generic (
        	DATA_WIDTH : integer := 8;
        	ADDR_WIDTH : integer := 12
    	);

    	port (
       		-- Clocks and reset
        	clk_wr : in std_logic;
        	clk_rd : in std_logic;
        	rst    : in std_logic;

        	-- Write side
        	wr_data      : in std_logic_vector(7 downto 0);
        	write_enable : in std_logic;
        	full         : out std_logic;

        	-- Read side
        	rd_data      : out std_logic_vector(7 downto 0);
        	read_enable  : in std_logic;
        	empty        : out std_logic
   	);	


	component Round_Robin
	port(
		clock 		: in std_logic; 
		reset 		: in std_logic; 

		empty 		: in std_logic_vector(NUM_PORTS - 1 downto 0); -- empty signal from fifos
		frame_done 	: in std_logic_vector(NUM_PORTS - 1 downto 0); -- end of frame
		read_en 	: out std_logic_vector(NUM_PORTS - 1 downto 0); 
		
		sel 		: out std_logic_vector(NUM_PORTS_WIDTH - 1 downto 0)
	); 

	begin

	fifo_mem_inst : fifo_mem
		port map(
			clk_wr => clk, 
			clk_rd => clk, 
			rst => rst,
			wr_data => input_data,
			write_enable => input_valid,
			full =>
			rd_data => output_data,
			read_enable => 
			empty => 	
		);

	Round_Robin_inst : Round_Robin
		port map(
			clock => clk,
			reset => rst,
			empty =>
			frame_done =>
			read_en =>
			sel => output_sel
		); 










		