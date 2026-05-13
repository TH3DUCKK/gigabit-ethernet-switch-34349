LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

use work.constants.all;

-- Description
-- This smaller FIFO holds metadata for the larger FIFO to keep track of packets.
-- NOTE: THIS HAS NO READ OR WRITE PROTECTION!

entity sync_fifo_64 is
  generic (
    DATA_WIDTH : integer := 16; -- (10 downto 0), packet length | (14 downto 11), destination port | (15) crc error
    DEPTH      : integer := 64;
    ADDR_WIDTH : integer := 6
  );
  port (
    clk        : in  std_logic;
    rst        : in  std_logic;

    -- Write interface
    wr_en      : in  std_logic;
    write_data : in  std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Read interface
    rd_en      : in  std_logic;
    read_data  : out std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Status signals
    full       : out std_logic;
    empty      : out std_logic
  );
end entity sync_fifo_64;

architecture rtl of sync_fifo_64 is
  component sync_mem_64
	port
	(
		clock      : in  std_logic;
		data       : in  std_logic_vector(15 downto 0);
		rdaddress  : in  std_logic_vector(5 downto 0);
		rden       : in  std_logic;
		wraddress  : in  std_logic_vector(5 downto 0);
		wren       : in  std_logic;
		q          : out std_logic_vector(15 downto 0)
	);
end component;
  
  -- Pointers and memory addresses
  signal rd_ptr   : std_logic_vector(6 downto 0);
  signal wr_ptr   : std_logic_vector(6 downto 0);
  signal rd_addr  : std_logic_vector(5 downto 0);
  signal wr_addr  : std_logic_vector(5 downto 0);

begin


  -- Memory instantiation
  u_sync_mem : sync_mem_64
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
        if rd_en = '1' then
          rd_ptr <= rd_ptr + 1;
        end if;
      end if;
    end if;
  end process;

  -- Memory addresses and pointers
  wr_addr <= wr_ptr(ADDR_WIDTH-1 downto 0);
  rd_addr <= rd_ptr(ADDR_WIDTH-1 downto 0);

  -- Full and empty
  full  <= '1' when (not (wr_ptr(ADDR_WIDTH)) & wr_ptr(ADDR_WIDTH - 1 downto 0)) = rd_ptr else '0';
  empty <= '1' when wr_ptr = rd_ptr else '0';

end architecture rtl;