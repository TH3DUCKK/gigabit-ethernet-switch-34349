LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity crossbar_double_fifo is 
	port (
		clk		: in std_logic; 
		rst		: in std_logic; 
		frame_data	: in std_logic_vector(7 downto 0); 
		frame_data_valid : in std_logic; 
		meta_data	: in std_logic_vector(15 downto 0); 
		meta_data_valid	: in std_logic; 
		port_data_out	: out std_logic_vector( 7 downto 0); 
		port_data_valid	: out std_logic;
		enough_space	: out std_logic := '0';
		end_of_frame 	: out std_logic;
		empty_frame_fifo: out std_logic; 
		RR_read_enable : in std_logic
	); 

end entity crossbar_double_fifo; 

architecture rtl of crossbar_double_fifo is

	-- signals for calculating space
	signal write_ptr_int 	: std_logic_vector(12 downto 0); 
	signal read_ptr_int		: std_logic_vector(12 downto 0); 
	constant frame_fifo_total_size : unsigned(12 downto 0) := to_unsigned(4095, 13);
	signal space_in_frame_fifo	: std_logic_vector(12 downto 0):= "1111111111111"; 

	-- signals to write meta_fifo
	signal meta_data_write_enable : std_logic := '0'; 
	
	-- signals for meta_data
	signal frame_size		: std_logic_vector(15 downto 0):= x"0000"; 
	signal meta_data_read_enable	: std_logic:= '0'; 
	signal reg_RR_read_enable 	: std_logic:= '0'; 
	signal reg_reg_RR_read_enable	: std_logic:= '0'; 
	signal reg_reg_reg_RR_read_enable : std_logic:= '0'; 


	--signal end_of_frame_value	: std_logic_vector(11 downto 0):= x"fff"; 
	--signal end_of_frame_int		: std_logic:='0'; 
	signal reg_end_of_enable_int	: std_logic;
	signal reg_reg_end_of_enable_int : std_logic; 
	signal end_of_enable_value	: std_logic_vector(11 downto 0) :=x"fff"; 
	signal end_of_enable_int	: std_logic := '0';	
	signal frame_fifo_read_enable	: std_logic:= '0'; 

	signal reg_read_enable		: std_logic:= '0'; 
	signal reg_reg_read_enable	: std_logic:= '0'; 

	signal empty_frame_fifo_int	: std_logic := '1'; 

	signal store_meta_data		: std_logic_vector(15 downto 0):= x"0000"; 

	-- FSM 

	type state_type is (IDLE, CHECK_SPACE,STORE_DATA, SEND_HANDSHAKE); 
	signal state, next_state : state_type;  
	

	component Frame_fifo
		port(
			clk 		: in std_logic; 
			rst		: in std_logic; 
			-- Write side
      			wr_data      	: in std_logic_vector(7 downto 0); 
			write_enable 	: in std_logic;
			-- Read side
      			rd_data      	: out std_logic_vector(7 downto 0);
      			read_enable  	: in std_logic; 
			write_ptr 	: out std_logic_vector(12 downto 0);
			read_ptr 	: out std_logic_vector(12 downto 0) 
		);

	end component;

	component Meta_fifo
		port(
			clk 		: in std_logic; 
			rst		: in std_logic; 
			-- Write side
      			wr_data      	: in std_logic_vector(15 downto 0); 
			write_enable 	: in std_logic;
			-- Read side
      			rd_data      	: out std_logic_vector(15 downto 0);
      			read_enable  	: in std_logic 	
		);

	end component;

	begin

	Frame_fifo_inst : Frame_fifo
		port map(
			clk => clk,
			rst => rst,		
      			wr_data => 	frame_data,    	
			write_enable => frame_data_valid,  	
      			rd_data => 	port_data_out,   	
      			read_enable => 	frame_fifo_read_enable, 	
			write_ptr => 	write_ptr_int, 
			read_ptr =>	read_ptr_int	
		); 


		Meta_fifo_inst : Meta_fifo
		port map(
			clk => clk,
			rst => rst,		
      			wr_data => 	store_meta_data,	    	
			write_enable => meta_data_write_enable, 
      			rd_data => 	frame_size,      	
      			read_enable =>  meta_data_read_enable 	
		); 

	-- this process calculates the free space in frame_fifo
	process(space_in_frame_fifo, read_ptr_int, write_ptr_int)
	begin
		if((read_ptr_int(12) xor write_ptr_int(12))= '1') then
			space_in_frame_fifo(11 downto 0) <= std_logic_vector(unsigned(read_ptr_int(11 downto 0)) - unsigned(write_ptr_int(11 downto 0))); 
			space_in_frame_fifo(12)<= '0'; 
		else
			space_in_frame_fifo <= std_logic_vector((frame_fifo_total_size) - (unsigned(write_ptr_int(11 downto 0)) - unsigned(read_ptr_int(11 downto 0)))); 	
		end if; 	
	end process; 


	-- RR_read_enable is delayed to match when frame_size is correct. 
	process(clk, rst)
	begin
    		if rst = '0' then
        		reg_RR_read_enable         <= '0';
        		reg_reg_RR_read_enable     <= '0';
        		reg_reg_reg_RR_read_enable <= '0';

    		elsif rising_edge(clk) then
        		reg_RR_read_enable         <= RR_read_enable;
        		reg_reg_RR_read_enable     <= reg_RR_read_enable;
        		reg_reg_reg_RR_read_enable <= reg_reg_RR_read_enable;
    		end if;
	end process;

	-- Calculate end_of_frame value. 
	process(clk) 
	begin
		if rising_edge(clk) then
			if reg_reg_reg_RR_read_enable = '1' then -- change this
				--end_of_frame_value <= std_logic_vector(unsigned(frame_size(11 downto 0)) + unsigned(read_ptr_int(11 downto 0)));
				end_of_enable_value <= std_logic_vector(unsigned(frame_size(10 downto 0)) + unsigned(read_ptr_int(11 downto 0))-2);  
			end if; 
		end if; 
	end process; 		
		

	-- end of frame
	process(clk) 
	begin
		if rising_edge(clk) then
			if (read_ptr_int(11 downto 0) = end_of_enable_value) then 
				end_of_enable_int <= '1';
			else
				end_of_enable_int <= '0';
			end if; 
		end if; 
	end process;  

	

	-- controles frame_fifo_read_enable
	process(clk)
	begin
    		if rising_edge(clk) then
        		if end_of_enable_int = '1' then
            			frame_fifo_read_enable <= '0';

        		elsif reg_reg_RR_read_enable = '1' then
            			frame_fifo_read_enable <= '1';

        		end if;
    		end if;
	end process; 

	--controles the valid signal on the output port.
	process(clk, rst)
	begin
    		if rst = '0' then
        		reg_read_enable        		<= '0';
        		reg_reg_read_enable     	<= '0';
        		reg_end_of_enable_int 		<= '0';
			reg_reg_end_of_enable_int 	<= '0';

		elsif rising_edge(clk) then
			reg_read_enable <= frame_fifo_read_enable; 
			reg_reg_read_enable <= reg_read_enable;
			reg_end_of_enable_int <= end_of_enable_int; 
			reg_reg_end_of_enable_int <= reg_end_of_enable_int; 
		end if; 
	end process; 

	-- make an empty signal for the frame_fifo
	process(clk)
	begin
		if rising_edge(clk) then
			if space_in_frame_fifo = "0111111111111"  then
				empty_frame_fifo_int <= '1'; 
			else
				empty_frame_fifo_int <= '0'; 
			end if; 
		end if; 
	end process; 


	--FSM to load
	seq : process(clk)
	begin
    		if rising_edge(clk) then

        -- synchronous reset
        	if rst = '0' then

            		state <= IDLE;
            		store_meta_data <= (others => '0');

        	else

            	-- state update
            	state <= next_state;

            	-- register metadata
            	if state = IDLE and meta_data_valid = '1' then
                	store_meta_data <= meta_data;
            	end if;

        	end if;
    	end if;
	end process seq;

	comp: process(state, meta_data, meta_data_valid, space_in_frame_fifo, frame_data_valid, store_meta_data)
	begin
		
		next_state <= state;
   		enough_space <= '0';
    		meta_data_write_enable <= '0';

		case(state) is 
			when IDLE => 
				if (meta_data_valid = '1') then
					next_state <= CHECK_SPACE;
				else 
					next_state <= IDLE; 
				end if; 
				
				enough_space <= '0'; 
				meta_data_write_enable <= '0';
				store_meta_data	<= meta_data; 
 
			when CHECK_SPACE => 
				if (store_meta_data(10 downto 0) < space_in_frame_fifo) then
					next_state <= STORE_DATA; 
				else
        				next_state <= CHECK_SPACE;
    				end if; 
					
				enough_space <= '0';  
				meta_data_write_enable <= '0';  	

			when STORE_DATA => 
					next_state <= SEND_HANDSHAKE;
			
					enough_space <= '1'; 
					meta_data_write_enable <= '1';  
	

			when SEND_HANDSHAKE => 
				if (frame_data_valid = '0') then
					next_state <= IDLE;
				else
                			next_state <= SEND_HANDSHAKE;
            			end if; 

				enough_space <= frame_data_valid; 
				meta_data_write_enable <= '0'; 
					
			end case; 
		end process comp;    

			 
	empty_frame_fifo <= empty_frame_fifo_int; 		
	end_of_frame <= reg_reg_end_of_enable_int;
	port_data_valid <= reg_reg_read_enable; 
	meta_data_read_enable <= RR_read_enable; 
	
end architecture rtl;

					  