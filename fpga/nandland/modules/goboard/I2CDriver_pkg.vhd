library IEEE;
use IEEE.std_logic_1164.all;

package I2CDriver_pkg is
    type t_Request_Type is (
        IDLE,
        READ,
        WRITE
    );
    type  t_Request_State is ( 
        IDLE,
        WORKING, 
        COMPLETED_OK,
        COMPLETED_ERROR
    );
end I2CDriver_pkg;


package body I2CDriver_pkg is 
end package body I2CDriver_pkg;