LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity Frame_fifo is 
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
end entity Frame_fifo;

architecture rtl of Frame_fifo is 
	
	--Write 
	signal waddr : std_logic_vector(11 downto 0) := x"000";
	signal raddr : std_logic_vector(11 downto 0) := x"000";
	signal read_en_int : std_logic := '0'; 
	signal write_en_int: std_logic := '0'; 
	signal write_ptr_int : std_logic_vector(12 downto 0):= "0000000000000"; 
	signal read_ptr_int : std_logic_vector(12 downto 0) := "0000000000000"; 

	component mem8X4096
		port(
			data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
			rdaddress	: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
			clock		: IN STD_LOGIC ;
			rden		: IN STD_LOGIC  := '1';
			wraddress	: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
			wren		: IN STD_LOGIC  := '0';
			q		: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
			); 

	end component;
	
	begin
	
	mem8X4096_inst : mem8X4096
		port map(
			data => wr_data,
			rdaddress => raddr,
			clock => clk,
			rden => read_en_int,
			wraddress => waddr,
			wren => write_en_int, 
			q => rd_data
		); 

	
	process(clk)
	begin
		if rising_edge(clk) then
			if (write_en_int = '1') then
				write_ptr_int <= write_ptr_int + 1;
			end if; 
		end if; 
	end process; 
			
	process(clk)
	begin
		if rising_edge(clk) then
			if (read_en_int = '1') then
				read_ptr_int <= read_ptr_int + 1;
			end if; 
		end if; 
	end process; 

			
	raddr <= read_ptr_int(11 downto 0); 
	waddr <= write_ptr_int(11 downto 0); 
	write_ptr <= write_ptr_int; 
	read_ptr <= read_ptr_int; 
	write_en_int <= write_enable; 
	read_en_int <= read_enable; 
	
end architecture rtl;
	
