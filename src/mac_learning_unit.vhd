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
    data_in  : in std_logic_vector (MAC_WORD_SIZE - 1 downto 0);
    address  : out std_logic_vector (MAC_RAM_SIZE_BITS - 1 downto 0);
    wren     : out std_logic;
    data_out : out std_logic_vector (MAC_WORD_SIZE - 1 downto 0)
  );
end entity mac_learning_unit;
architecture rtl of mac_learning_unit is

  -- Declarations (internal signals, types, etc.)

  -- States
  type state_type is (IDLE, FORWARD_READ, FORWARD_WAIT,  FORWARD_CHECK, LEARN_READ, LEARN_WAIT,  LEARN_CHECK, DONE);

  -- Registers
  signal dest_port_reg, dest_port_reg_next : std_logic_vector(NUM_PORTS - 1 downto 0) := (others => '0');
  signal state, state_next                 : state_type                               := IDLE;

  -- Wires

  --dest_port_reg enable signal
  signal dest_port_reg_enable : std_logic;

  -- Outputs from the MAC RAM and signals to get the port and MAC information
  signal port_memory : std_logic_vector(NUM_PORTS - 1 downto 0);
  signal mac_memory  : std_logic_vector(MAC_SIZE - 1 downto 0);
  signal mac_age     : std_logic_vector(MAC_WORD_SIZE - MAC_SIZE - NUM_PORTS - 1 downto 0); -- Age information for overwriting entries

begin
  process (clk, rst)
  begin
    if rising_edge(clk) then
      if rst = '0' then
        -- Reset logic
        state         <= IDLE;
        dest_port_reg <= (others => '0');
      else
        state         <= state_next;
        if dest_port_reg_enable = '1' then
          dest_port_reg <= dest_port_reg_next;
        else
          dest_port_reg <= dest_port_reg; -- Hold the value if not enabled (to handle having regs on MAC RAM inputs and outputs)
        end if;
      end if;
    end if;
  end process;

  process (valid, src_port, source_mac, dest_mac, data_in, clk, dest_port_reg_enable, port_memory, mac_memory, mac_age, state, dest_port_reg, wren)
  begin
    -- Default outputs
    state_next         <= state;
    dest_port          <= dest_port_reg;
    dest_port_reg_next <= dest_port_reg;
    ready              <= '0';
    wren               <= '0';
    dest_port_reg_enable <= '0';
    address            <= (others => '0');
    data_out           <= (others => '0');
    port_memory        <= (others => '0');
    mac_memory         <= (others => '0');
    mac_age            <= (others => '0');

    case state is
      when IDLE =>
        if valid = '1' then
          state_next <= FORWARD_READ;
        end if;

      when FORWARD_READ =>
        -- Hash the destination MAC to get the address for the MAC RAM
        address    <= dest_mac(MAC_RAM_SIZE_BITS - 1 downto 0); -- Simple hash using lower 13 bits
        state_next <= FORWARD_WAIT;

      when FORWARD_WAIT =>
        -- Wait for the MAC RAM read to complete (beacause of output register in the MAC RAM)
        state_next <= FORWARD_CHECK;

      when FORWARD_CHECK =>
        -- Check if the destination MAC is known (i.e. if the port is not zero)
        dest_port_reg_enable <= '1'; -- Enable the dest_port_reg to update the output port
        mac_memory  <= data_in(MAC_WORD_SIZE - 1 downto MAC_WORD_SIZE - MAC_SIZE); -- MAC information is stored in the upper bits
        port_memory <= data_in(MAC_WORD_SIZE - MAC_SIZE - 1 downto MAC_WORD_SIZE - MAC_SIZE - NUM_PORTS); -- Port information is stored in the 4 bits after MAC information

        if mac_memory = dest_mac then
          dest_port_reg_next <= port_memory; -- Forward to the known port
        else
          assert mac_memory /= dest_mac
          report "No hit in lookup flooding ports"
            severity FAILURE;

          --dest_port_reg_next <= std_logic_vector'(dest_port_reg_next'range => '1') xor src_port; -- Flood to all ports except source
          --dest_port_reg_next <= std_logic_vector(to_unsigned((2**NUM_PORTS) - 1, NUM_PORTS)) xor src_port; -- Flood to all ports except source
          dest_port_reg_next <= not src_port; -- Flood to all ports except source
        end if;

        state_next <= LEARN_READ;

      when LEARN_READ =>
        -- Hash the source MAC to get the address for the MAC RAM
        address    <= source_mac(MAC_RAM_SIZE_BITS - 1 downto 0);
        state_next <= LEARN_WAIT;
    
      when LEARN_WAIT =>
        -- Wait for the MAC RAM read to complete (beacause of output register in the MAC RAM)
        state_next <= LEARN_CHECK;

      when LEARN_CHECK =>
        -- Check if the source MAC is already in the table
        address    <= source_mac(MAC_RAM_SIZE_BITS - 1 downto 0); -- Address for learning is based on the source MAC
        mac_memory  <= data_in(MAC_WORD_SIZE - 1 downto MAC_WORD_SIZE - MAC_SIZE); -- MAC information is stored in the upper bits
        port_memory <= data_in(MAC_WORD_SIZE - MAC_SIZE - 1 downto MAC_WORD_SIZE - MAC_SIZE - NUM_PORTS); -- Port is stored in the next 4 bits
        mac_age     <= data_in(MAC_WORD_SIZE - MAC_SIZE - NUM_PORTS - 1 downto 0); -- Age information is stored in the remaining bits
        --wren        <= '0';
        --data_out                                                                           <= (others => '0'); -- Default to zero for padding
        --data_out(MAC_WORD_SIZE - 1 downto MAC_WORD_SIZE - MAC_SIZE)                        <= source_mac; -- Store the source MAC in the upper bits
        --data_out(MAC_WORD_SIZE - MAC_SIZE - 1 downto MAC_WORD_SIZE - MAC_SIZE - NUM_PORTS) <= src_port; -- Store the source port in the next 4 bits
        data_out <= source_mac & src_port & std_logic_vector(to_unsigned(0, MAC_WORD_SIZE - MAC_SIZE - NUM_PORTS)); -- Store the source MAC in the upper bits, port in the next, age 0

        -- Case 1: If the hashed source MAC is in the table and it is a perfect match (same MAC and port), reset the age counter.
        if mac_memory = source_mac and port_memory = src_port then
          assert mac_memory = source_mac and port_memory = src_port
            report "Error in learning: something is wrong with the MAC RAM read/write logic"
            severity failure;
          wren <= '1'; -- Reset the age counter
          -- Case 2: If the hashed source MAC is in the table but the max age has been reached, overwrite it with the new MAC and port.
        elsif to_integer(unsigned(mac_age)) = MAC_AGE_MAX then
          assert to_integer(unsigned(mac_age)) = MAC_AGE_MAX
            report "Error in learning: something is wrong with the MAC RAM age counter logic"
            severity failure;
          wren <= '1';
          -- Case 3: If the hashed source MAC is empty, add it with the corresponding source port. (Assuming that we never get an all zero mac address)
        elsif unsigned(mac_memory) = 0 then
          assert unsigned(mac_memory) = 0
            report "Error in learning: something is wrong with the MAC RAM empty entry logic"
            severity failure;
          wren <= '1';
        end if;

        state_next <= DONE;

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
