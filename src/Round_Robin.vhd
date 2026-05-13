library ieee; 
use ieee.std_logic_1164.all; 
use ieee.numeric_std.all; 
use ieee.std_logic_unsigned.all;

use work.constants.all;

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
		
		sel 		: out std_logic_vector(3 downto 0)
	); 

	end Round_Robin; 

architecture rtl of Round_Robin is 
	
	signal count_int 	: std_logic_vector(3 downto 0):= "0001"; 
	signal count_int_prev 	: std_logic_vector(3 downto 0):= "0001"; 
	signal count_en	 	: std_logic:= '0'; 
	type state_type is (ALL_EMPTY, PICK_FIFO, READ_ENABLE, TRANSMIT); 
	signal state, next_state : state_type;  

begin

	
	-- sequentiel logic
	
	count : process(clock, reset)
	begin
    		if (reset = '0') then
       		 	count_int <= "0001";  
    		elsif rising_edge(clock) then
       			if (count_en = '1') then

            			count_int <= count_int(2 downto 0) & count_int(3);
				count_int_prev <= count_int; 

        		end if;
    		end if;
	end process count;


	seq: process(clock, reset)
	begin
		if (reset = '0') then 
			state <= ALL_EMPTY; 
		elsif(rising_edge(clock)) then 
			state <= next_state; 
		end if; 
	end process seq; 

	comp: process(state, empty, frame_done, count_int)-- check for all signals
	begin
		case(state) is 
			when ALL_EMPTY => 
				if (empty /= "1111") then
					next_state <= PICK_FIFO;
				end if; 
				
					count_en <= '0'; 
					read_en <= "0000"; 
					sel <= "0000";
 
			when PICK_FIFO => 
				if ((empty and count_int )= "0000") then
					next_state <= READ_ENABLE; 
				end if; 
					count_en <= '1'; 
					read_en <= "0000"; 
					sel <= "0000";
			
			when READ_ENABLE =>
					next_state <= TRANSMIT;
				
		 			count_en <= '0'; 
					read_en <= count_int_prev; 
					sel <= count_int_prev;

			when TRANSMIT =>
				if (empty = "1111") then 
					next_state <= ALL_EMPTY;
	
				elsif (frame_done /= "0000") then
					next_state <= PICK_FIFO;

				end if; 
		 			count_en <= '0'; 
					read_en <= "0000"; 
					sel <= count_int_prev;


		
		
			end case; 
		end process comp;  	
				
end rtl; 































