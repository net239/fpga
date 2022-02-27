library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Vga_Driver  is
    generic (
        -- refer https://web.mit.edu/6.111/www/s2004/NEWKIT/vga.shtml
        g_hActiveVideo : integer := 640;
        g_hFrontPorch : integer := 16;
        g_hSyncPulse : integer := 96;
        g_hBackPorch : integer := 48;

        g_vActiveVideo : integer := 480;
        g_vFrontPorch : integer := 11;
        g_vSyncPulse : integer := 2;
        g_vBackPorch : integer := 31
    );
    port (
        -- Main Clock (25 MHz)
        i_Clk         : in std_logic;

        --output horizental and vertical positions
        o_hPos  : out integer range 0 to 800;
        o_vPos  : out integer  range 0 to 524;

        --output - is video on 
        o_isVideoOn : out std_logic;

        --output hSync and vSync
        o_hSync : output std_logic;
        o_vSync : output std_logic
    );

end entity Vga_Driver;

architecture RTL of Vga_Driver is
begin

    process_Scan : process (i_Clk)
    begin

    end;
end;