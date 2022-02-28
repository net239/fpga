library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--Simple VGA driver, assumes clock is at 25MHZ
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

        --output horizontal and vertical positions
        o_hPos  : out integer ;
        o_vPos  : out integer  ;

        --output - is video on 
        o_isVideoOn : out std_logic;

        --output hSync and vSync
        o_hSync : out std_logic;
        o_vSync : out std_logic
    );

end entity Vga_Driver;

architecture RTL of Vga_Driver is

    signal r_hPos  : integer range 0 to 800 := 0;
    signal r_vPos  : integer range 0 to 524:= 0;
    signal r_hSync : std_logic := '0';
    signal r_vSync : std_logic := '0';
    signal r_isVideoOn : std_logic := '0';

    type VGAStateMachine is ( 
                state_Idle, state_ActiveVideo, state_FrontPorch, state_SyncPulse, state_BackPorch
            );
    signal r_VGAHorizontalStateMachine : VGAStateMachine := state_Idle;
    signal r_VGAVerticalStateMachine : VGAStateMachine := state_Idle;

begin

    --process drives the horizontal beam
    process_driveHorizontalBeam : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            case r_VGAHorizontalStateMachine is
            when state_Idle =>   
                r_hPos <= 0;
                r_hSync <= '1';
                r_VGAHorizontalStateMachine <= state_ActiveVideo;
            when state_ActiveVideo => 
                if r_hPos < (g_hActiveVideo - 1 ) then
                    r_hSync <= '1';
                    r_hPos <= r_hPos + 1;
                elsif r_hPos = (g_hActiveVideo - 1) then
                    r_hSync <= '1';
                    r_hPos <= r_hPos + 1;
                    r_VGAHorizontalStateMachine <= state_FrontPorch;
                end if;
            when state_FrontPorch => 
                if r_hPos < (g_hActiveVideo + g_hFrontPorch - 1)  then
                    r_hSync <= '1';
                    r_hPos <= r_hPos + 1;
                elsif r_hPos = (g_hActiveVideo + g_hFrontPorch - 1)  then
                    r_hSync <= '0';
                    r_hPos <= r_hPos + 1;
                    r_VGAHorizontalStateMachine <= state_SyncPulse;
                end if;
            when state_SyncPulse => 
                if r_hPos < (g_hActiveVideo + g_hFrontPorch + g_hSyncPulse - 1)  then
                    r_hSync <= '0';
                    r_hPos <= r_hPos + 1;
                elsif r_hPos = (g_hActiveVideo + g_hFrontPorch + g_hSyncPulse - 1)  then
                    r_hSync <= '1';
                    r_hPos <= r_hPos + 1;
                    r_VGAHorizontalStateMachine <= state_BackPorch;
                end if;
            when state_BackPorch => 
                if r_hPos < (g_hActiveVideo + g_hFrontPorch + g_hSyncPulse + g_hBackPorch - 1)  then
                    r_hSync <= '1';
                    r_hPos <= r_hPos + 1;
                elsif r_hPos = (g_hActiveVideo + g_hFrontPorch + g_hSyncPulse + g_hBackPorch - 1)  then
                    r_hSync <= '1';
                    r_hPos <= 0;
                    r_VGAHorizontalStateMachine <= state_ActiveVideo;
                end if;
            when others =>
                r_VGAHorizontalStateMachine <= state_Idle;
            end case;
        end if;
    end process process_driveHorizontalBeam;

    process_driveVerticalBeam : process (i_Clk , r_hPos )
    begin
        if rising_edge(i_Clk) then
            if r_hPos = (g_hActiveVideo + g_hFrontPorch + g_hSyncPulse + g_hBackPorch - 1)  then
                r_vPos <= r_vPos + 1;  -- important increment vertical beam , when at end of horizontal line
            end if;

            case r_VGAVerticalStateMachine is
            when state_Idle =>   
                r_vPos <= 0;
                r_vSync <= '1';
                r_VGAVerticalStateMachine <= state_ActiveVideo;    
            when state_ActiveVideo => 
                if r_vPos < (g_vActiveVideo - 1 ) then
                    r_vSync <= '1';
                elsif r_vPos = (g_vActiveVideo - 1) then
                    r_vSync <= '1';
                    r_VGAVerticalStateMachine <= state_FrontPorch;
                end if;
            when state_FrontPorch => 
                if r_vPos < (g_vActiveVideo + g_vFrontPorch - 1)  then
                    r_vSync <= '1';
                elsif r_vPos = (g_vActiveVideo + g_vFrontPorch - 1)  then
                    r_vSync <= '0';
                    r_VGAVerticalStateMachine <= state_SyncPulse;
                end if;
            when state_SyncPulse => 
                if r_vPos < (g_vActiveVideo + g_vFrontPorch + g_vSyncPulse - 1)  then
                    r_vSync <= '0';
                elsif r_vPos = (g_vActiveVideo + g_vFrontPorch + g_vSyncPulse - 1)  then
                    r_vSync <= '1';
                    r_VGAVerticalStateMachine <= state_BackPorch;
                end if;
            when state_BackPorch => 
                if r_vPos < (g_vActiveVideo + g_vFrontPorch + g_vSyncPulse + g_vBackPorch - 1)  then
                    r_vSync <= '1';
                elsif r_vPos = (g_vActiveVideo + g_vFrontPorch + g_vSyncPulse + g_vBackPorch - 1)  then
                    r_vSync <= '1';
                    r_vPos <= 0;
                    r_VGAVerticalStateMachine <= state_ActiveVideo;
                end if;
            when others =>
                r_VGAVerticalStateMachine <= state_Idle;    
            end case;
        end if;
    end process process_driveVerticalBeam;

    process_setActiveVideo  : process (i_Clk,r_VGAHorizontalStateMachine,r_VGAVerticalStateMachine ) 
    begin 
        if rising_edge(i_Clk) then            
            if (r_hPos < g_hActiveVideo  ) and (r_vPos <  g_vActiveVideo  )  then
                r_isVideoOn <= '1';
            else
                r_isVideoOn <= '0';
            end if;
        end if;
    end process process_setActiveVideo;
    
    o_vPos <= r_vPos;
    o_hPos <= r_hPos;
    o_hSync <= r_hSync;
    o_vSync <= r_vSync;
    o_isVideoOn <= r_isVideoOn;
end;