library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

entity crossbar is
  	port (
    		-- Clock and reset
    		clk 			: in std_logic; 	
		rst 			: in std_logic; 

		-- PORT 0
		frame_data_0 		: in std_logic_vector(31 downto 0); 
		frame_data_valid_0 	: in std_logic_vector(3 downto 0); 
		meta_data_0		: in std_logic_vector(63 downto 0); 
		meta_data_valid_0 	: in std_logic_vector(3 downto 0); 
		
		port_data_out_0 	: out std_logic_vector(7 downto 0); 
		port_data_valid_0 	: out std_logic_vector(3 downto 0); 
		enough_space_0		: out std_logic_vector(3 downto 0);

		-- PORT 1
		frame_data_1 		: in std_logic_vector(31 downto 0); 
		frame_data_valid_1 	: in std_logic_vector(3 downto 0); 
		meta_data_1		: in std_logic_vector(63 downto 0); 
		meta_data_valid_1 	: in std_logic_vector(3 downto 0); 
		
		port_data_out_1 	: out std_logic_vector(7 downto 0); 
		port_data_valid_1 	: out std_logic_vector(3 downto 0); 
		enough_space_1		: out std_logic_vector(3 downto 0);

		-- PORT 2
		frame_data_2 		: in std_logic_vector(31 downto 0); 
		frame_data_valid_2 	: in std_logic_vector(3 downto 0); 
		meta_data_2		: in std_logic_vector(63 downto 0); 
		meta_data_valid_2 	: in std_logic_vector(3 downto 0); 
		
		port_data_out_2 	: out std_logic_vector(7 downto 0); 
		port_data_valid_2 	: out std_logic_vector(3 downto 0); 
		enough_space_2		: out std_logic_vector(3 downto 0);

		-- PORT 3
		frame_data_3 		: in std_logic_vector(31 downto 0); 
		frame_data_valid_3 	: in std_logic_vector(3 downto 0); 
		meta_data_3		: in std_logic_vector(63 downto 0); 
		meta_data_valid_3 	: in std_logic_vector(3 downto 0); 
		
		port_data_out_3 	: out std_logic_vector(7 downto 0); 
		port_data_valid_3 	: out std_logic_vector(3 downto 0); 
		enough_space_3		: out std_logic_vector(3 downto 0)

  		);
end entity crossbar;

	architecture rtl of crossbar is 
 
	
	component Output_port_X
	
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
	end component Output_port_X; 

	begin

	Output_port_0_inst : Output_port_X
		port map(
			 		
        	clk => clk,   	
		rst => rst, 		 
		frame_data => frame_data_0, 	 
		frame_data_valid => frame_data_valid_0,   
		meta_data => meta_data_0,	
		meta_data_valid => meta_data_valid_0,   
		
		port_data_out => port_data_out_0,	 
		port_data_valid => port_data_valid_0,   
		enough_space => enough_space_0	
   	);	

	Output_port_1_inst : Output_port_X
		port map(
			 		
        	clk => clk,   	
		rst => rst, 		 
		frame_data => frame_data_1, 	 
		frame_data_valid => frame_data_valid_1,   
		meta_data => meta_data_1,	
		meta_data_valid => meta_data_valid_1,   
		
		port_data_out => port_data_out_1,	 
		port_data_valid => port_data_valid_1,   
		enough_space => enough_space_1	
   	);	

	Output_port_2_inst : Output_port_X
		port map(
			 		
        	clk => clk,   	
		rst => rst, 		 
		frame_data => frame_data_2, 	 
		frame_data_valid => frame_data_valid_2,   
		meta_data => meta_data_2,	
		meta_data_valid => meta_data_valid_2,   
		
		port_data_out => port_data_out_2,	 
		port_data_valid => port_data_valid_2,   
		enough_space => enough_space_2	
   	);	
	
	Output_port_3_inst : Output_port_X
		port map(
			 		
        	clk => clk,   	
		rst => rst, 		 
		frame_data => frame_data_3, 	 
		frame_data_valid => frame_data_valid_3,   
		meta_data => meta_data_3,	
		meta_data_valid => meta_data_valid_3,   
		
		port_data_out => port_data_out_3,	 
		port_data_valid => port_data_valid_3,   
		enough_space => enough_space_3	
   	);	


end architecture rtl; 









		