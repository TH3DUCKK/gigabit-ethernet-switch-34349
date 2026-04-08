library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.constants.all;

-- Description:
-- This module implements the MAC learning unit for a gigabit Ethernet switch.
-- It learns the source MAC addresses from incoming frames and updates the MAC address table.
-- The module interfaces with the data parking and crossbar modules to receive frame information and update the MAC address table accordingly.

-- Route first
-- Then map the source to the port

-- Algorithm: (Currently replaces at every collision)
-- 1. On receiving a valid input, read the data.
-- 2. Use destination MAC to determine the output port (if known).
-- 3a. If the destination MAC is known, forward the frame to the corresponding port.
-- 3b. If the destination MAC is unknown, flood the frame to all ports except the source port.
-- 4. Check if the source MAC is already in the MAC address table.
-- 5a. If the source MAC is not in the table, add it with the corresponding source port.
-- 5b. If the hashed source MAC is in the table but the port or MAC is different, update the entry with the new port or MAC.

entity mac_learning_unit is
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
    dest_port : out std_logic_vector(NUM_PORTS - 1 downto 0); -- One bit per port

    -- MAC_RAM interface
    data_in : in std_logic_vector (63 downto 0);
    address : out std_logic_vector (12 downto 0);
    wren : out std_logic;
    data_out : out std_logic_vector (63 downto 0)
  );
end entity mac_learning_unit;
architecture rtl of mac_learning_unit is

  -- Declarations (internal signals, types, etc.)

  -- States
  type state_type is (IDLE, FORWARD_READ, FORWARD_CHECK, LEARN_READ, LEARN_CHECK, DONE);

  -- Registers
  signal dest_port_reg, dest_port_reg_next : std_logic_vector(NUM_PORTS - 1 downto 0) := (others => '0');
  signal state, state_next                 : state_type := IDLE;

  -- Wires

  -- Outputs from the MAC RAM and signals to get the port and MAC information
  signal port_memory : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal mac_memory  : std_logic_vector(MAC_SIZE - 1 downto 0);


  -- Constant
  constant WORD_SIZE : integer := 64; -- Size of each entry in the MAC RAM ( 48 bits for MAC + padding + 4 bits for port )

begin
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

  process (valid, dest_mac, source_mac, src_port, state, state_next, clk)
  begin
    -- Default outputs
    ready              <= '0';
    dest_port          <= dest_port_reg;
    dest_port_reg_next <= dest_port_reg;
    state_next         <= state;

    case state is
      when IDLE =>
        if valid = '1' then
          state_next <= FORWARD_READ;
        end if;

      when FORWARD_READ =>
        -- Hash the destination MAC to get the address for the MAC RAM
        address  <= dest_mac(12 downto 0); -- Simple hash using lower 13 bits
        state_next <= FORWARD_CHECK;

      when FORWARD_CHECK =>
        -- Check if the destination MAC is known (i.e. if the port is not zero)
        port_memory <= data_in(NUM_PORTS - 1 downto 0); -- Port information is stored in the lower 4 bits
        mac_memory  <= data_in(WORD_SIZE - 1 downto WORD_SIZE - MAC_SIZE); -- MAC information is stored in the upper bits
        
        if mac_memory = dest_mac then
          dest_port_reg_next <= port_memory; -- Forward to the known port
        else
          dest_port_reg_next <= std_logic_vector'(dest_port_reg_next'range => '1') xor src_port; -- Flood to all ports except source
        end if;

        state_next <= LEARN_READ;

      when LEARN_READ =>
        -- Hash the source MAC to get the address for the MAC RAM
        address  <= source_mac(12 downto 0);
        state_next <= LEARN_CHECK;

      when LEARN_CHECK =>
        -- Check if the source MAC is already in the table
        port_memory <= data_in(NUM_PORTS - 1 downto 0); -- Port is stored in the lower 4 bits
        mac_memory  <= data_in(WORD_SIZE - 1 downto WORD_SIZE - MAC_SIZE); -- MAC information is stored in the upper bits
        data_out     <= source_mac & "000000000000" & src_port; -- Store MAC, padding (64-48-4 = 12 bits) and port together
        if mac_memory = source_mac then
          if port_memory = src_port then
            state_next <= DONE;
          else
            wren     <= '1';
          end if;
        else
          wren     <= '1';
        end if;
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
