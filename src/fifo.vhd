LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fifo is
    generic (
        DATA_WIDTH : integer := 64;
        ADDR_WIDTH : integer := 8
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
        empty        : out std_logic;

        -- Memory interface
        ram_wr_en   : out std_logic;
        ram_wr_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        ram_wr_data : out std_logic_vector(DATA_WIDTH-1 downto 0);
        ram_rd_en   : out std_logic;
        ram_rd_addr : out std_logic_vector(ADDR_WIDTH-1 downto 0);
        ram_rd_data : in  std_logic_vector(DATA_WIDTH-1 downto 0)
    );
end entity fifo;

architecture rtl of fifo is
    -- Write clk domain signals
	--signal waddr : std_logic_vector(ADDR_WIDTH - 1 downto 0);
	--signal wen : std_logic;
	signal wptr : std_logic_vector(ADDR_WIDTH downto 0);
	signal wptr_gray : std_logic_vector(ADDR_WIDTH downto 0);
	signal rptr_gray_tmp_sync : std_logic_vector(ADDR_WIDTH downto 0);
	signal rptr_gray_sync : std_logic_vector(ADDR_WIDTH downto 0);
	signal full : std_logic;
	
	-- Read clk domain signals
	--signal raddr : std_logic_vector(ADDR_WIDTH - 1 downto 0);
	--signal ren : std_logic;
	signal rptr : std_logic_vector(ADDR_WIDTH downto 0);
	signal rptr_gray : std_logic_vector(ADDR_WIDTH downto 0);
	signal wptr_gray_tmp_sync : std_logic_vector(ADDR_WIDTH downto 0);
	signal wptr_gray_sync : std_logic_vector(ADDR_WIDTH downto 0);
	signal empty : std_logic;

begin
    process(clk_wr)
    begin
        if rising_edge(clk_wr) then
            if rst = '1' then
                ram_wr_en <= '0';
                wptr <= (others => '0');
                wptr_gray <= (others => '0');
                rptr_gray_tmp_sync <= (others => '0');
                rptr_gray_sync <= (others => '0');
            else
                -- Write control logic
                if write_enable = '1' and full = '0' then
                    ram_wr_en <= '1';
                    wptr <= wptr + 1;
                else
                    ram_wr_en <= '0';
                end if;

                -- Convert binary to gray
                wptr_gray(ADDR_WIDTH - 1) <= wptr(ADDR_WIDTH - 1);
                for i in (ADDR_WIDTH - 2) downto 0 loop
                    wptr_gray(i) <= wptr(i) xor wptr(i + 1);
                end loop;

                -- Synchronize pointers
                rptr_gray_tmp_sync <= rptr_gray;
                rptr_gray_sync <= rptr_gray_tmp_sync;
            end if;

        end if;
    end process;

    process(clk_rd)
    begin
        if rising_edge(clk_rd) then
            if rst = '1' then
                ram_rd_en <= '0';
                rptr <= (others => '0');
                rptr_gray <= (others => '0');
                wptr_gray_tmp_sync <= (others => '0');
                wptr_gray_sync <= (others => '0');
            else
                -- Read control logic
                if read_enable = '1' and empty = '0' then
                    ram_rd_en <= '1';
                    rptr <= rptr + 1;
                else
                    ram_rd_en <= '0';
                end if;

                -- Convert binary to gray
                rptr_gray(ADDR_WIDTH - 1) <= rptr(ADDR_WIDTH - 1);
                for i in (ADDR_WIDTH - 2) downto 0 loop
                    rptr_gray(i) <= rptr(i) xor rptr(i + 1);
                end loop;

                -- Synchronize pointers
                wptr_gray_tmp_sync <= wptr_gray;
                wptr_gray_sync <= wptr_gray_tmp_sync;
            end if;

        end if;
    end process;

    -- Full and empty signals
    full <= (not (wptr_gray(ADDR_WIDTH)) & wptr_gray(ADDR_WIDTH - 1 downto 0)) = rptr_gray_sync;
    empty <= wptr_gray_sync = rptr_gray;

    -- Address signals
    ram_wr_addr <= wptr(ADDR_WIDTH - 2 downto 0);
    ram_rd_addr <= rptr(ADDR_WIDTH - 2 downto 0);

    -- Memory connections
    rd_data <= ram_rd_data;
    ram_wr_data <= wr_data;

end architecture rtl;