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

    signal r_hPos  : integer range 0 	to (g_hActiveVideo + g_hFrontPorch + g_hSyncPulse + g_hBackPorch - 1) 
    				 					:= 0;
    signal r_vPos  : integer range 0 to  (g_vActiveVideo + g_vFrontPorch + g_vSyncPulse + g_vBackPorch - 1) 
    									:= 0 ;
    signal r_hSync : std_logic := '0';
    signal r_vSync : std_logic := '0';
    signal r_hVideoOn : std_logic := '0';
    signal r_vVideoOn : std_logic := '0';
    signal r_reset : std_logic := '1';

begin

    --process drives the horizontal beam
    process_driveHorizontalBeam : process (i_Clk, r_reset)
    begin
        if rising_edge(i_Clk) then
        	if r_reset = '1' then
            	r_hPos <= 0;
            else
              -- check if we are at the end of horizental beam scan  	
              if r_hPos = (g_hActiveVideo + g_hFrontPorch + g_hSyncPulse + g_hBackPorch - 1)  then
                  r_hPos <= 0;
              else 
                  r_hPos <= r_hPos + 1;
              end if;
            end if;
        end if;
   end process process_driveHorizontalBeam;
            
   
    process_driveVerticalBeam : process (i_Clk , r_reset, r_hPos )
    begin
        if rising_edge(i_Clk) then  
            if r_reset = '1' then
            	r_vPos <= 0;
            else
            	-- check if we are at the end of horizental beam scan
            	if r_hPos = (g_hActiveVideo + g_hFrontPorch + g_hSyncPulse + g_hBackPorch - 1) then
                	-- check if we are at the end of vertical beam scan
                	if r_vPos = (g_vActiveVideo + g_vFrontPorch + g_vSyncPulse + g_vBackPorch - 1)  then
                    	r_vPos <= 0;
                	else 
                        r_vPos <= r_vPos + 1;
                    end if;
                end if;
             end if;
        end if;
    end process process_driveVerticalBeam;

     
    proces_setSyncHorizontal : process (i_Clk,r_reset, r_hPos ) 
    begin 
        if rising_edge(i_Clk) then   
        	if r_reset = '1' then
            	r_hSync <= '1';
            else
              if (r_hPos >= g_hActiveVideo + g_hFrontPorch - 1)  and
                 (r_hPos < g_hActiveVideo + g_hFrontPorch + g_hSyncPulse - 1)  then
                  r_hSync <= '0';
              else
                  r_hSync <= '1';
              end if;
            end if;
        end if;
    end process proces_setSyncHorizontal;
    
    proces_setSyncVertical : process (i_Clk,r_reset,r_vPos, r_hPos ) 
    begin 
        if rising_edge(i_Clk) then  
        	if r_reset = '1' then
            	r_vSync <= '1';
            else
              -- check if we are at the end of horizental beam scan  	
              if r_hPos = (g_hActiveVideo + g_hFrontPorch + g_hSyncPulse + g_hBackPorch - 1)  then
                -- set vSync to 0 when we are vertically inside sync area 
                if (r_vPos >= g_vActiveVideo + g_vFrontPorch - 1)  and 
                   (r_vPos < g_vActiveVideo + g_vFrontPorch + g_vSyncPulse - 1) then
                    r_vSync <= '0';
                else
                    r_vSync <= '1';
                end if;
               end if;
            end if;
        end if;
    end process proces_setSyncVertical;
    
    proces_setVideoOnHorizontal : process (i_Clk,r_reset, r_hPos ) 
    begin 
        if rising_edge(i_Clk) then   
        	if r_reset = '1' then
            	r_hVideoOn <= '1';
            else
              if (r_hPos >= g_hActiveVideo - 1)  then 
                   -- check if we are at the end of horizental beam scan  
              	  if r_hPos = (g_hActiveVideo + g_hFrontPorch + g_hSyncPulse + g_hBackPorch - 1)  then	
                  	r_hVideoOn <= '1';
                  else
                  	r_hVideoOn <= '0';
                  end if;
              else
                  r_hVideoOn <= '1';
              end if;
            end if;
        end if;
    end process proces_setVideoOnHorizontal;
    
    proces_setVideoOnVertical : process (i_Clk,r_reset,r_vPos, r_hPos ) 
    begin 
        if rising_edge(i_Clk) then  
        	if r_reset = '1' then
            	r_vVideoOn <= '1';
            else
                if (r_vPos >= g_vActiveVideo - 1)  then 
                    -- check if we are at the end of vertical beam scan  	
                    if r_vPos = (g_vActiveVideo + g_vFrontPorch + g_vSyncPulse + g_vBackPorch - 1)  then
                        r_vVideoOn <= '0';
                    else
                        r_vVideoOn <= '1';
                    end if;
                else
                    r_vVideoOn <= '1';
                end if;
            end if;
        end if;
    end process proces_setVideoOnVertical;
    
    process_reset : process (i_Clk, r_reset)
    begin
    	if rising_edge(i_Clk) then    
        	r_reset <= '0';
        end if;
    end process process_reset;
    
    o_vPos <= r_vPos;
    o_hPos <= r_hPos;
    o_hSync <= r_hSync;
    o_vSync <= r_vSync;
    o_isVideoOn <= r_hVideoOn and r_vVideoOn;
end;