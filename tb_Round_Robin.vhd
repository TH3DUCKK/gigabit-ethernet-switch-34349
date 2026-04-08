library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_Round_Robin is
end tb_Round_Robin;

architecture behavior of tb_Round_Robin is

    component Round_Robin
        port(
            clock       : in std_logic;
            reset       : in std_logic;
            empty       : in std_logic_vector(3 downto 0);
            frame_done  : in std_logic_vector(3 downto 0);
            read_en     : out std_logic_vector(3 downto 0);
            sel         : out std_logic_vector(1 downto 0)
        );
    end component;

    signal clock       : std_logic := '0';
    signal reset       : std_logic := '0';
    signal empty       : std_logic_vector(3 downto 0) := "0000";
    signal frame_done  : std_logic_vector(3 downto 0) := "0000";
    signal read_en     : std_logic_vector(3 downto 0);
    signal sel         : std_logic_vector(1 downto 0);

    constant clk_period : time := 10 ns;

begin

    uut: Round_Robin
        port map (
            clock       => clock,
            reset       => reset,
            empty       => empty,
            frame_done  => frame_done,
            read_en     => read_en,
            sel         => sel
        );

    clk_process : process
    begin
        while true loop
            clock <= '0';
            wait for clk_period / 2;
            clock <= '1';
            wait for clk_period / 2;
        end loop;
    end process;

    stim_proc: process
    begin
        -- Reset
        reset <= '1';
        wait for 20 ns;
        reset <= '0';

        -- Test 1: all empty 
        empty <= "1111";
        frame_done <= "0000";
        wait for 50 ns;

        -- Test 2: channel 0 empty
        empty <= "1011";
        wait for 50 ns;

        -- Test 3: channel 1 frame done
        empty <= "1001";
        frame_done <= "0100";
        wait for 50 ns;

        -- Test 4: multiple active
        empty <= "1111";
        frame_done <= "0010";
        wait for 100 ns;

        -- Finish simulation
        wait;
    end process;

end behavior;