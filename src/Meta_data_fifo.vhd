LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;


entity Meta_data_fifo is
    generic (
        DATA_WIDTH : integer := 16;
        ADDR_WIDTH : integer := 6
    );
    port (
        -- Clocks and reset
        clk    : in std_logic;
        rst    : in std_logic;

        -- Write side
        wr_data      : in std_logic_vector(15 downto 0);
        write_enable : in std_logic;
        full         : out std_logic;

        -- Read side
        rd_data      : out std_logic_vector(15 downto 0);
        read_enable  : in std_logic;
        empty        : out std_logic

       
    );
end entity Meta_data_fifo ;

architecture rtl of Meta_data_fifo  is

	-- Write
	signal waddr : std_logic_vector(ADDR_WIDTH - 1 downto 0) := "000000";
	signal wen : std_logic;
	signal wptr : std_logic_vector(ADDR_WIDTH downto 0):= "0000000";
	signal full_internal : std_logic;
	
	-- Read 
	signal raddr : std_logic_vector(ADDR_WIDTH - 1 downto 0) := "000000";
	signal ren : std_logic;
	signal rptr : std_logic_vector(ADDR_WIDTH downto 0):= "0000000";
	signal empty_internal : std_logic;

	component mem_64
		port(
			data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			rdaddress	: IN STD_LOGIC_VECTOR (5 DOWNTO 0);
			rdclock		: IN STD_LOGIC ;
			rden		: IN STD_LOGIC  := '1';
			wraddress	: IN STD_LOGIC_VECTOR (5 DOWNTO 0);
			wrclock		: IN STD_LOGIC  := '1';
			wren		: IN STD_LOGIC  := '0';
			q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
			); 

	end component;

begin

	mem_inst : mem_64
		port map(
			data => wr_data,
			rdaddress => raddr,
			rdclock => clk,
			rden => ren,
			wraddress => waddr,
			wrclock => clk, 
			wren => wen, 
			q => rd_data
		); 

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                
                wptr <= (others => '0');
              
            else
                -- Write control logic
                if write_enable = '1' and full_internal = '0' then
                    --ram_wr_en <= '1';
                    wptr <= wptr + 1;
                else
                    --ram_wr_en <= '0';
                end if;

            end if;

        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                rptr <= (others => '0');  
            else
                -- Read control logic
                if read_enable = '1' and empty_internal = '0' then
                    rptr <= rptr + 1;
                else
                    --rd_en_internal <= '0';
                end if;             
            end if;

        end if;
    end process;

    	-- Full and empty signals
	full_internal <= '1' when (not (wptr(ADDR_WIDTH)) & wptr(ADDR_WIDTH - 1 downto 0)) = rptr else '0'; 
	full <= full_internal;
 	empty_internal <= '1' when wptr = rptr else '0';
	empty <= empty_internal;


	waddr <= wptr(ADDR_WIDTH-1 downto 0);
	raddr <= rptr(ADDR_WIDTH-1 downto 0);

	wen <= write_enable and not full_internal;
	ren <= read_enable and not empty_internal;
  

end architecture rtl;
