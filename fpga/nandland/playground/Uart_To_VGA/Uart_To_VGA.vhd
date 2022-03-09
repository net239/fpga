library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.font_en_crt_pkg.all;

-- send characters from UART to VGA
entity Uart_To_VGA is
    port (
        -- Main Clock (25 MHz)
        i_Clk         : in std_logic;

        -- input wire that gives us bits 
        i_UART_RX     : in std_logic;

        -- output wire to echo back what we got
        o_UART_TX     : out std_logic;

         -- LED dislay - Segment1 is higher digit, Segment2 is lower digit
        o_Segment1_A  : out std_logic;
        o_Segment1_B  : out std_logic;
        o_Segment1_C  : out std_logic;
        o_Segment1_D  : out std_logic;
        o_Segment1_E  : out std_logic;
        o_Segment1_F  : out std_logic;
        o_Segment1_G  : out std_logic;
        
        o_Segment2_A  : out std_logic;
        o_Segment2_B  : out std_logic;
        o_Segment2_C  : out std_logic;
        o_Segment2_D  : out std_logic;
        o_Segment2_E  : out std_logic;
        o_Segment2_F  : out std_logic;
        o_Segment2_G  : out std_logic;

        -- vga
        o_VGA_HSync : out std_logic;
        o_VGA_VSync : out std_logic;

        o_VGA_Red_0 : out std_logic;
        o_VGA_Red_1 : out std_logic;
        o_VGA_Red_2 : out std_logic;
        o_VGA_Grn_0 : out std_logic;
        o_VGA_Grn_1 : out std_logic;
        o_VGA_Grn_2 : out std_logic;
        o_VGA_Blu_0 : out std_logic;
        o_VGA_Blu_1 : out std_logic;
        o_VGA_Blu_2 : out std_logic
    );
end entity Uart_To_VGA;

architecture RTL of Uart_To_VGA is
    signal r_byte_read     : std_logic_vector(7 downto 0);  --byte read from UART
    signal r_byte_read_ready : std_logic := '0';  -- byte from UART is ready 
    signal r_byte_display     : std_logic_vector(7 downto 0) := 0;  -- byte to shown on the display
    
    signal r_Uart_Tx_Active : std_logic := '0'; 
    signal r_UART_TX     : std_logic;

    signal w_Segment1_A, w_Segment2_A : std_logic;
    signal w_Segment1_B, w_Segment2_B : std_logic;
    signal w_Segment1_C, w_Segment2_C : std_logic;
    signal w_Segment1_D, w_Segment2_D : std_logic;
    signal w_Segment1_E, w_Segment2_E : std_logic;
    signal w_Segment1_F, w_Segment2_F : std_logic;
    signal w_Segment1_G, w_Segment2_G : std_logic;

    signal r_isVideoOn     : std_logic;
    signal r_hPos  : integer range 0 to 800 := 0;
    signal r_vPos  : integer range 0 to 524:= 0;

    signal r_fontRow_Index:  integer := 0;   -- row index of one single line of pixels in complete font set
    signal r_fontPixels_row: std_logic_vector(work.font_en_crt_pkg.FONT_WIDTH-1 downto 0);  --  one single line of pixels in complete font set -  at the above index
    signal r_fontRow_Current_Pixel : std_logic := '0';    -- current pixel from the font row, select based on hPos in video display

    signal r_hTextPos : integer := 200;  -- horizental and vertical text poistion on display
    signal r_vTextPos : integer := 200;

    
  begin
    
    -- instantiate UART receiver
    Uart_Rx_Inst : entity work.Uart_Rx
        port map (
            i_Clk        => i_Clk,
            i_Uart_Serial_Rx    => i_UART_RX,
            o_Byte_Read => r_byte_read,
            o_Byte_Ready => r_byte_read_ready
    );

    -- instantiate UART sender
    Uart_Tx_Inst : entity work.Uart_Tx
        port map (
            i_Clk        => i_Clk,
            o_Uart_Serial_Tx    => r_UART_TX,
            o_Uart_Tx_Active => r_Uart_Tx_Active,
            i_Byte_To_Send => r_byte_read,
            i_Byte_Ready_To_send => r_byte_read_ready
    );

    -- Instantiate VGA driver
    Vga_Driver_Inst : entity work.Vga_Driver
        port map (
            i_Clk        => i_Clk,
            o_hPos  => r_hPos,
            o_vPos  => r_vPos,
    
            --output - is video on 
            o_isVideoOn => r_isVideoOn,
    
            --output hSync and vSync
            o_hSync => o_VGA_HSync,
            o_vSync => o_VGA_VSync
    );

    -- Instantiate Binary to 7-Segment Converter
    SevenSeg1_Inst : entity work.Binary_To_7Segment
        port map (
        i_Clk        => i_Clk,
        i_Binary_Num => r_byte_read(7 downto 4),
        o_Segment_A  => w_Segment1_A,
        o_Segment_B  => w_Segment1_B,
        o_Segment_C  => w_Segment1_C,
        o_Segment_D  => w_Segment1_D,
        o_Segment_E  => w_Segment1_E,
        o_Segment_F  => w_Segment1_F,
        o_Segment_G  => w_Segment1_G
    );

    SevenSeg2_Inst : entity work.Binary_To_7Segment
        port map (
        i_Clk        => i_Clk,
        i_Binary_Num => r_byte_read(3 downto 0),
        o_Segment_A  => w_Segment2_A,
        o_Segment_B  => w_Segment2_B,
        o_Segment_C  => w_Segment2_C,
        o_Segment_D  => w_Segment2_D,
        o_Segment_E  => w_Segment2_E,
        o_Segment_F  => w_Segment2_F,
        o_Segment_G  => w_Segment2_G
    );


    --font for VGA driver
    Font_en_Inst : entity work.Font_en_crt
        port map (
            i_Clk        => i_Clk,
            i_fontRow_Index => r_fontRow_Index ,
            o_fontPixels_row => r_fontPixels_row
    );

            
    -- these are all NOT becuase Go board makes LED light up when its low
    o_Segment2_A <= not w_Segment2_A;
    o_Segment2_B <= not w_Segment2_B;
    o_Segment2_C <= not w_Segment2_C;
    o_Segment2_D <= not w_Segment2_D;
    o_Segment2_E <= not w_Segment2_E;
    o_Segment2_F <= not w_Segment2_F;
    o_Segment2_G <= not w_Segment2_G;


    o_Segment1_A <= not w_Segment1_A;
    o_Segment1_B <= not w_Segment1_B;
    o_Segment1_C <= not w_Segment1_C;
    o_Segment1_D <= not w_Segment1_D;
    o_Segment1_E <= not w_Segment1_E;
    o_Segment1_F <= not w_Segment1_F;
    o_Segment1_G <= not w_Segment1_G;

    -- send output only when UART TX is active
    o_UART_TX <= r_UART_TX   when r_Uart_Tx_Active = '1'  else '1';

    -- simple function to display square grid on VGA - for testing purposes
    -- process_draw : process (i_Clk)
    -- begin
    --     if rising_edge(i_Clk) then
    --         if r_isVideoOn = '1' then
    --             if r_hPos mod 20 = 0 or r_hPos = 639 or r_vPos mod 20 = 0 or r_vPos = 479 then
    --                 o_VGA_Red_0 <= '1';
    --                 o_VGA_Red_1 <= '0';
    --                 o_VGA_Red_2 <= '1';

    --                 o_VGA_Grn_0 <= '1';
    --                 o_VGA_Grn_1 <= '0';
    --                 o_VGA_Grn_1 <= '1';

    --                 o_VGA_Blu_0 <= '1';
    --                 o_VGA_Blu_1 <= '0';
    --                 o_VGA_Blu_2 <= '1';
    --             else
    --                 o_VGA_Red_0 <= '0';
    --                 o_VGA_Red_1 <= '0';
    --                 o_VGA_Red_2 <= '0';

    --                 o_VGA_Grn_0 <= '0';
    --                 o_VGA_Grn_1 <= '0';
    --                 o_VGA_Grn_1 <= '0';

    --                 o_VGA_Blu_0 <= '0';
    --                 o_VGA_Blu_1 <= '0';
    --                 o_VGA_Blu_2 <= '0';
    --             end if;
    --         else
    --             o_VGA_Red_0 <= '0';
    --             o_VGA_Red_1 <= '0';
    --             o_VGA_Red_2 <= '0';

    --             o_VGA_Grn_0 <= '0';
    --             o_VGA_Grn_1 <= '0';
    --             o_VGA_Grn_1 <= '0';

    --             o_VGA_Blu_0 <= '0';
    --             o_VGA_Blu_1 <= '0';
    --             o_VGA_Blu_2 <= '0';
    --         end if;
    --     end if; 
    -- end process process_draw;

    -- fetch the byte to be displayed     
    process_updateByteToDisplay : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
          if r_byte_read_ready = '1' then
                r_byte_display <= r_byte_read;
          end if;
        end if;
    end process process_updateByteToDisplay;

    -- update start of font row index
    process_updateFontRowStartIndex : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
          if r_vPos >= r_vTextPos - 1  and r_vPos < r_vTextPos + work.font_en_crt_pkg.FONT_HEIGHT -1  then
                r_fontRow_Index <=  to_integer((unsigned(r_byte_display)) * work.font_en_crt_pkg.FONT_HEIGHT )+ (r_vPos - r_vTextPos + 1);
          else
                r_fontRow_Index <= 0;
          end if;
        end if;
    end process process_updateFontRowStartIndex;
    
    -- update current pixel value
    process_updateFontRowCurrentPixel : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
          if r_hPos >= r_hTextPos - 1  and r_hPos < r_hTextPos + work.font_en_crt_pkg.FONT_WIDTH -1 then
                -- NOTE we subtract from  work.font_en_crt_pkg.FONT_WIDTH -1 becuase the r_fontPixels_row goes from WIDTH downto 0, we need to flip it
            	r_fontRow_Current_Pixel <=  r_fontPixels_row( work.font_en_crt_pkg.FONT_WIDTH - 1 - (r_hPos - r_hTextPos + 1));
           else 
                r_fontRow_Current_Pixel <= '0';    
           end if;
        end if;
    end process process_updateFontRowCurrentPixel;

    process_write_text : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            if r_isVideoOn = '1' then
                --check if current pixel position is inside the text area
                if r_hPos >= r_hTextPos and r_hPos < r_hTextPos + work.font_en_crt_pkg.FONT_WIDTH and
                    r_vPos >= r_vTextPos and r_vPos < r_vTextPos + work.font_en_crt_pkg.FONT_HEIGHT then

                        if r_fontRow_Current_Pixel = '1' then 
                            o_VGA_Red_0 <= '1';
                            o_VGA_Red_1 <= '1';
                            o_VGA_Red_2 <= '1';

                            o_VGA_Grn_0 <= '1';
                            o_VGA_Grn_1 <= '1';
                            o_VGA_Grn_1 <= '1';
            
                            o_VGA_Blu_0 <= '1';
                            o_VGA_Blu_1 <= '1';
                            o_VGA_Blu_2 <= '1';
                        else
                            o_VGA_Red_0 <= '0' ;
                            o_VGA_Red_1 <= '0';
                            o_VGA_Red_2 <= '0';

                            o_VGA_Grn_0 <= '0';
                            o_VGA_Grn_1 <= '0';
                            o_VGA_Grn_1 <= '0';
            
                            o_VGA_Blu_0 <= '0';
                            o_VGA_Blu_1 <= '0';
                            o_VGA_Blu_2 <= '0';
                        end if;

                        
                else
                        o_VGA_Red_0 <= '0';
                        o_VGA_Red_1 <= '0';
                        o_VGA_Red_2 <= '0';
        
                        o_VGA_Grn_0 <= '0';
                        o_VGA_Grn_1 <= '0';
                        o_VGA_Grn_1 <= '0';
        
                        o_VGA_Blu_0 <= '0';
                        o_VGA_Blu_1 <= '0';
                        o_VGA_Blu_2 <= '0';
                end if;
            end if;
        end if;
    end process process_write_text;
end architecture RTL;    