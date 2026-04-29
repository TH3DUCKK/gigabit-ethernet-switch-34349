LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.constants.all;

-- Description
-- This large FIFO holds data packets coming directly from the CRC.
-- If an error is detected the data can be "deleted" from the FIFO
-- by moving the read pointer past the error-filled data packet.
-- almost_full signal goes high 1 clock cycle before the FIFO is full.
-- NOTE: THIS HAS NO READ OR WRITE PROTECTION!

entity sync_fifo_4096 is
  generic (
    DATA_WIDTH : integer := 8;
    DEPTH      : integer := 4096;
    ADDR_WIDTH : integer := 12
  );
  port (
    clk           : in  std_logic;
    rst           : in  std_logic;

    -- Write interface
    wr_en         : in  std_logic;
    write_data    : in  std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Read interface
    rd_en         : in  std_logic;
    read_data     : out std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Read pointer control signals
    jump_read_ptr : in  std_logic;
    jump_size     : in  std_logic_vector(10 downto 0);

    -- Status signals
    full          : out std_logic;
    almost_full   : out std_logic;
    empty         : out std_logic
  );
end entity sync_fifo_4096;

architecture rtl of sync_fifo_4096 is
  component sync_mem_4096
	port
	(
		clock      : in  std_logic;
		data       : in  std_logic_vector(7 downto 0);
		rdaddress  : in  std_logic_vector(11 downto 0);
		rden       : in  std_logic;
		wraddress  : in  std_logic_vector(11 downto 0);
		wren       : in  std_logic;
		q          : out std_logic_vector(7 downto 0)
	);
end component;
  
  -- Pointers and memory addresses
  signal rd_ptr   : std_logic_vector(12 downto 0); -- One wider to account for full and empty flags
  signal wr_ptr   : std_logic_vector(12 downto 0); -- One wider to account for full and empty flags
  signal rd_addr  : std_logic_vector(11 downto 0);
  signal wr_addr  : std_logic_vector(11 downto 0);

begin

  -- Memory instantiation
  u_sync_mem : sync_mem_4096
    port map
    (
      clock      => clk,
      data       => write_data,
      rdaddress  => rd_addr,
      rden       => rd_en,
      wraddress  => wr_addr,
      wren       => wr_en,
      q          => read_data
    );

  -- Write process
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        wr_ptr <= (others => '0');
      else
        if wr_en = '1' then
          wr_ptr <= wr_ptr + 1;
        end if;
      end if;
    end if;
  end process;

  -- Read process
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        rd_ptr <= (others => '0');
      else
        -- Move read pointer to "delete" data
        if jump_read_ptr = '1' then
          rd_ptr <= rd_ptr + jump_size;
        elsif rd_en = '1' then -- Or increment normally
          rd_ptr <= rd_ptr + 1;
        end if;
      end if;
    end if;
  end process;

  -- Memory addresses and pointers
  wr_addr <= wr_ptr(ADDR_WIDTH-1 downto 0);
  rd_addr <= rd_ptr(ADDR_WIDTH-1 downto 0);

  -- full, almost_full and empty signals
  full  <= '1' when (not (wr_ptr(ADDR_WIDTH)) & wr_ptr(ADDR_WIDTH - 1 downto 0)) = rd_ptr else '0';
  almost_full  <= '1' when (not (wr_ptr(ADDR_WIDTH)) & (wr_ptr(ADDR_WIDTH - 1 downto 0) - 1)) = rd_ptr else '0';
  empty <= '1' when wr_ptr = rd_ptr else '0';

end architecture rtl;