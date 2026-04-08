library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use ieee.std_logic_unsigned.all;

use work.constants.all;

-- !!!!!!!!!! valid signal? !!!!!!!!!!!!!!!!!!!

--=======================================================================
-- This entity implements a round robin function for selecting the connection between the inputs and the output.
-- A counter changes between pointing at each fifo. If the fifo is empty the counter increases.
-- If a fifo has a frame when the counter points at it, the frame will be transmittet to the output.
-- When the frame is done the counter will point to the next fifo.  
--=======================================================================


entity Round_Robin is 
	port( 
		clock 		: in std_logic; 
		reset 		: in std_logic; 

		empty 		: in std_logic_vector(NUM_PORTS - 1 downto 0); -- empty signal from fifos
		frame_done 	: in std_logic_vector(NUM_PORTS - 1 downto 0); -- end of frame
		read_en 	: out std_logic_vector(NUM_PORTS - 1 downto 0); 
		
		sel 		: out std_logic_vector(NUM_PORTS_WIDTH - 1 downto 0)
	); 

	end Round_Robin; 

architecture rtl of Round_Robin is 
	
	signal count_int 	: std_logic_vector(NUM_PORTS_WIDTH - 1  downto 0); 
	signal count_int_hot 	: std_logic_vector(NUM_PORTS - 1 downto 0);  
	signal count_en	 	: std_logic; 

begin

	cnt_Mux : process (count_int, empty, frame_done)
	begin 
		case count_int is 
			when "00" => count_en <= empty(0) OR frame_done(0); 
			when "01" => count_en <= empty(1) OR frame_done(1); 
			when "10" => count_en <= empty(2) OR frame_done(2);
			when "11" => count_en <= empty(3) OR frame_done(3);
			when others => count_en <= '0'; 
		end case; 
	end process cnt_Mux; 

	-- counter is one-hot-code where each bit controle a read enable of a fifo 
	one_hot_conv : process (count_int)
	begin
		case count_int is 
			when "00" => count_int_hot <= "0001"; 
			when "01" => count_int_hot <= "0010"; 
			when "10" => count_int_hot <= "0100";
			when "11" => count_int_hot <= "1000";  
			when others => count_int_hot <= "0000"; 
		end case; 
	end process one_hot_conv; 


	count : process (clock, reset, count_en)
	begin 
		if (reset = '1') then
			count_int <= "00"; 
		elsif rising_edge(clock) then 
			if (count_en = '1') then  
				count_int <= count_int + '1'; 
			end if; 
		end if; 
	end process count; 


	read_en <= count_int_hot and not empty; 
	sel <= count_int; 
	
end rtl; 































