library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package constants is

  -- General constants
  constant NUM_PORTS      : integer := 4;
  constant NUM_PORTS_WIDTH: integer := 2; 
  constant BITS_PER_PORT  : integer := 8;
  constant DATA_BUS_WIDTH : integer := NUM_PORTS * BITS_PER_PORT;
  constant VALID_BITS     : integer := NUM_PORTS;
  constant ERROR_BITS     : integer := NUM_PORTS;
  constant MAC_SIZE       : integer := 48;

  -- MAC learning unit constants
  constant MAC_RAM_SIZE_BITS : integer := 13; -- Number of entries in the MAC RAM
  constant MAC_WORD_SIZE : integer := 64; -- Size of each entry in bits (48 bits for MAC + 4 bits for port + padding)
  
  -- BOTH SHOULD BE UPDATED AT THE SAME TIME
  constant MAC_AGE_MAX : integer := 300; -- time in seconds = (2**MAC_RAM_SIZE_BITS * MAC_AGE_CLOCK_DIVISION * 4) / freq
  constant MAC_AGE_CLOCK_DIVISION : integer := 1144408; -- MAC_AGE_CLOCK_DIVISION = MAC_AGE_MAX / (2**MAC_RAM_SIZE_BITS * 4 * freq)
  --constant MAC_AGE_MAX : integer := 5; -- Testing value
  --constant MAC_AGE_CLOCK_DIVISION : integer := 1; -- Testing value

end package constants;