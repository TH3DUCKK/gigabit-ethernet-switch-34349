library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Description:
-- This module implements the MAC learning unit for a gigabit Ethernet switch.
-- It learns the source MAC addresses from incoming frames and updates the MAC address table.
-- The module interfaces with the data parking and crossbar modules to receive frame information and update the MAC address table accordingly.

-- Route first
-- Then map the source to the port

-- Algorithm:
-- 1. On receiving a valid input, read the data.
-- 2. Use destination MAC to determine the output port (if known).
-- 3a. If the destination MAC is known, forward the frame to the corresponding port.
-- 3b. If the destination MAC is unknown, flood the frame to all ports except the source port.
-- 4. Check if the source MAC is already in the MAC address table.
-- 5a. If the source MAC is not in the table, add it with the corresponding source port.
-- 5b. If the hashed source MAC is in the table but the port or MAC is different, update the entry with the new port or MAC.
entity mac_learning_unit is
  generic (
    NUM_PORTS      : integer := 4;
    BITS_PER_PORT  : integer := 8;
    DATA_BUS_WIDTH : integer := NUM_PORTS * BITS_PER_PORT;
    VALID_BITS     : integer := NUM_PORTS;
    ERROR_BITS     : integer := NUM_PORTS;
    MAC_SIZE       : integer := 48
  );
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
end entity mac_learning_unit;
architecture rtl of mac_learning_unit is

  -- Declarations (internal signals, types, etc.)
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

  -- States
  type state_type is (IDLE, FORWARD_READ, FORWARD_CHECK, LEARN_READ, LEARN_CHECK, LEARN_WRITE, DONE);

  -- Registers
  signal dest_port_reg, dest_port_reg_next : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal state, state_next                 : state_type := IDLE;

  -- Wires

  -- Signals for interfacing with the MAC RAM
  signal address_a : std_logic_vector(12 downto 0);
  signal data_a    : std_logic_vector(63 downto 0);
  signal wren_a    : std_logic;

  -- Outputs from the MAC RAM and signals to get the port and MAC information
  signal q_a         : std_logic_vector(63 downto 0);
  signal port_memory : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal mac_memory  : std_logic_vector(MAC_SIZE - 1 downto 0);
  -- Temporary signals for since the second port is unused for now.
  signal address_b_tmp : std_logic_vector(12 downto 0) := (others => '0');
  signal data_b_tmp    : std_logic_vector(63 downto 0) := (others => '0');
  signal wren_b_tmp    : std_logic                     := '0';
  signal q_b_tmp       : std_logic_vector(63 downto 0) := (others => '0');

  -- Constant
  constant WORD_SIZE : integer := 64; -- Size of each entry in the MAC RAM ( 48 bits for MAC + padding + 4 bits for port )

begin

  MAC_RAM_inst : MAC_RAM
  port map
  (
    address_a => address_a,
    address_b => address_b_tmp,
    clock     => clk,
    data_a    => data_a,
    data_b    => data_b_tmp,
    wren_a    => wren_a,
    wren_b    => wren_b_tmp,
    q_a       => q_a,
    q_b       => q_b_tmp
  );

  process (clk, rst)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        -- Reset logic
        state         <= IDLE;
        dest_port_reg <= (others => '0');
      else
        state         <= state_next;
        dest_port_reg <= dest_port_reg_next;
      end if;
    end if;
  end process;

  process (ready, valid, dest_mac, source_mac, src_port)
  begin
    -- Default outputs
    ready              <= '0';
    dest_port          <= (others => '0');
    dest_port_reg_next <= dest_port_reg;
    state_next         <= state;

    case state is
      when IDLE =>
        if valid = '1' then
          state_next <= FORWARD_READ;
        end if;

      when FORWARD_READ =>
        -- Hash the destination MAC to get the address for the MAC RAM
        address_a  <= dest_mac(12 downto 0); -- Simple hash using lower 13 bits
        state_next <= FORWARD_CHECK;

      when FORWARD_CHECK =>
        -- Check if the destination MAC is known (i.e., if the port is not zero)
        port_memory <= q_a(NUM_PORTS - 1 downto 0); -- Port information is stored in the lower 4 bits
        mac_memory  <= q_a(WORD_SIZE - 1 downto WORD_SIZE - MAC_SIZE); -- MAC information is stored in the upper bits
        if port_memory /= (others => '0') then
          dest_port_reg_next <= port_memory; -- Forward to the known port
          state_next         <= Done;
        else
          dest_port_reg_next <= (others => '1') xor src_port;
          state_next         <= LEARN_READ;
        end if;

      when LEARN_READ =>
        -- Hash the source MAC to get the address for the MAC RAM
        address_a  <= source_mac(12 downto 0);
        state_next <= LEARN_CHECK;

      when LEARN_CHECK =>
        -- Check if the source MAC is already in the table
        port_memory <= q_a(NUM_PORTS - 1 downto 0); -- Port is stored in the lower 4 bits
        mac_memory  <= q_a(WORD_SIZE - 1 downto WORD_SIZE - MAC_SIZE); -- MAC information is stored in the upper bits
        if mac_memory = source_mac then
          if port_memory /= src_port then
            state_next <= LEARN_WRITE; -- Update with new port if different
          else
            state_next <= Done; -- No update needed
          end if;
        else
          state_next <= LEARN_WRITE; -- Add new entry if MAC is not in table
        end if;

      when LEARN_WRITE =>
        data_a     <= source_mac & "000000000000" & src_port; -- Store MAC and port together
        wren_a     <= '1'; -- Write enable for learning
        state_next <= Done;

      when DONE =>
        ready <= '1'; -- Indicate that the unit is ready for the next frame
        if valid = '0' then
          state_next <= IDLE; -- Wait for the next valid input
        end if;

      when others =>
        state_next <= IDLE;
    end case;
  end process;

end architecture;
