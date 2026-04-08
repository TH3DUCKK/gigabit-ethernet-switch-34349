library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.constants.all;

entity mac_learning_top is
  port (
    -- Clock and reset
    clk : in std_logic;
    rst : in std_logic;
    -- Mac inputs
    valid      : in std_logic;
    src_port   : in std_logic_vector(NUM_PORTS - 1 downto 0); -- One bit per port
    source_mac : in std_logic_vector(MAC_SIZE - 1 downto 0);
    dest_mac   : in std_logic_vector(MAC_SIZE - 1 downto 0);
    -- Mac outputs
    ready     : out std_logic;
    dest_port : out std_logic_vector(NUM_PORTS - 1 downto 0) -- One bit per port
  );
end entity mac_learning_top;

architecture rtl of mac_learning_top is

  -- Component declaration
  component mac_learning_unit is
    port (
      -- Clock and reset
      clk : in std_logic;
      rst : in std_logic;
      -- Mac inputs
      valid      : in std_logic;
      src_port   : in std_logic_vector(NUM_PORTS - 1 downto 0); -- One bit per port
      source_mac : in std_logic_vector(MAC_SIZE - 1 downto 0);
      dest_mac   : in std_logic_vector(MAC_SIZE - 1 downto 0);
      -- Mac outputs
      ready     : out std_logic;
      dest_port : out std_logic_vector(NUM_PORTS - 1 downto 0) -- One bit per port
    );
  end component mac_learning_unit;

  component MAC_RAM
    port (
      address_a : in std_logic_vector (12 downto 0);
      address_b : in std_logic_vector (12 downto 0);
      clock     : in std_logic := '1';
      data_a    : in std_logic_vector (63 downto 0);
      data_b    : in std_logic_vector (63 downto 0);
      wren_a    : in std_logic := '0';
      wren_b    : in std_logic := '0';
      q_a       : out std_logic_vector (63 downto 0);
      q_b       : out std_logic_vector (63 downto 0)
    );
  end component;

  component mac_clearing_unit is
    port (
      -- Clock and reset
      clk : in std_logic;
      rst : in std_logic;

      -- Input signals
      data_in : in std_logic_vector (63 downto 0);

      -- Output signals
      address : out std_logic_vector (12 downto 0);
      wren : out std_logic;
      data_out : out std_logic_vector (63 downto 0) 
    );
  end component;

  -- Wires for interconnecting the components
  signal data_in_mac_clearing : std_logic_vector (63 downto 0);
  signal address_mac_clearing : std_logic_vector (12 downto 0);
  signal wren_mac_clearing : std_logic;
  signal data_out_mac_clearing : std_logic_vector (63 downto 0);

  signal address_mac_learning : std_logic_vector (12 downto 0);
  signal data_in_mac_learning : std_logic_vector (63 downto 0);
  signal wren_mac_learning : std_logic;
  signal data_out_mac_learning : std_logic_vector (63 downto 0);

  begin

    mac_learning_unit_inst: entity work.mac_learning_unit
     port map(
        clk => clk,
        rst => rst,
        valid => valid,
        src_port => src_port,
        source_mac => source_mac,
        dest_mac => dest_mac,
        ready => ready,
        dest_port => dest_port,
        data_in => data_in_mac_learning,
        address => address_mac_learning,
        wren => wren_mac_learning,
        data_out => data_out_mac_learning
    );

    MAC_RAM_inst: entity work.MAC_RAM
     port map(
        address_a => address_mac_learning,
        address_b => address_mac_clearing,
        clock => clk,
        data_a => data_out_mac_learning,
        data_b => data_out_mac_clearing,
        wren_a => wren_mac_learning,
        wren_b => wren_mac_clearing,
        q_a => data_in_mac_learning,
        q_b => data_in_mac_clearing
    );

    mac_clearing_unit_inst: entity work.mac_clearing_unit
     port map(
        clk => clk,
        rst => rst,
        data_in => data_in_mac_clearing,
        address => address_mac_clearing,
        wren => wren_mac_clearing,
        data_out => data_out_mac_clearing
    );

end architecture;