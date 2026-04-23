LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;


ENTITY tb_fifo IS
END ENTITY;

ARCHITECTURE behavior OF tb_fifo IS

    -- Constants
    CONSTANT DATA_WIDTH : integer := 8;
    CONSTANT ADDR_WIDTH : integer := 12;

    -- DUT signals
    SIGNAL clk           : std_logic := '0';
    SIGNAL rst           : std_logic := '1';

    SIGNAL wr_data       : std_logic_vector(7 downto 0) := (others => '0');
    SIGNAL write_enable  : std_logic := '0';
    SIGNAL full          : std_logic;

    SIGNAL rd_data       : std_logic_vector(7 downto 0);
    SIGNAL read_enable   : std_logic := '0';
    SIGNAL empty         : std_logic;

    -- Clock period
    CONSTANT clk_period : time := 10 ns;

    --------------------------------------------------------------------
    -- Component Declaration
    --------------------------------------------------------------------
    COMPONENT fifo
        GENERIC (
            DATA_WIDTH : integer := 8;
            ADDR_WIDTH : integer := 12
        );
        PORT (
            clk    : IN std_logic;
            rst    : IN std_logic;

            wr_data      : IN std_logic_vector(7 downto 0);
            write_enable : IN std_logic;
            full         : OUT std_logic;

            rd_data      : OUT std_logic_vector(7 downto 0);
            read_enable  : IN std_logic;
            empty        : OUT std_logic
        );
    END COMPONENT;

BEGIN

    --------------------------------------------------------------------
    -- Instantiate DUT
    --------------------------------------------------------------------
    uut: fifo
        PORT MAP (
            clk => clk,
            rst => rst,
            wr_data => wr_data,
            write_enable => write_enable,
            full => full,
            rd_data => rd_data,
            read_enable => read_enable,
            empty => empty
        );

    --------------------------------------------------------------------
    -- Clock generation
    --------------------------------------------------------------------
    clk_process :process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    --------------------------------------------------------------------
    -- Stimulus process
    --------------------------------------------------------------------
    stim_proc: process
    begin
        ----------------------------------------------------------------
        -- RESET And check for empty
        ----------------------------------------------------------------
        wait for 20 ns;
        rst <= '0';
        wait for clk_period;

	assert empty = '1'
    	report "ERROR: Expected full to be '1'"
    	severity error;
	
        ----------------------------------------------------------------
        -- Fill fifo and check for full
        ----------------------------------------------------------------
        for j in 0 to 15 loop
		for i in 0 to 255 loop
            		wr_data <= std_logic_vector(to_unsigned(i, 8));
            		write_enable <= '1';
            	wait for clk_period;
        	end loop;
	end loop; 

	wait for 20 ns; -- Check if wen is cut of
	
        write_enable <= '0';

	assert full = '1'
    	report "ERROR: Expected full to be '1'"
    	severity error;

        wait for 20 ns;

        ----------------------------------------------------------------
        -- Read all data and check for empty
        ----------------------------------------------------------------
        for i in 0 to 4096 loop
            read_enable <= '1';
            wait for clk_period;
        end loop;

	wait for 20 ns; -- Check if ren is cut of

        read_enable <= '0';

	assert empty = '1'
    	report "ERROR: Expected empty to be '0'"
    	severity error;

        wait for 20 ns;

        ----------------------------------------------------------------
        -- MIXED OPERATIONS
        ----------------------------------------------------------------
        --for i in 16 to 31 loop
        --  wr_data <= std_logic_vector(to_unsigned(i, 8));
        -- write_enable <= '1';
        --  read_enable <= '1';
        --  wait for clk_period;
        --end loop;

        --write_enable <= '0';
        --read_enable  <= '0';

        --wait for 50 ns;

        ----------------------------------------------------------------
        -- END SIM
        ----------------------------------------------------------------
        assert false report "Simulation Finished" severity failure;

    end process;

END;
