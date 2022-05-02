library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;


-- Display current temprature on 7 segment LED display
entity DisplayTempOnSevenSegment is
    port (
        -- Main Clock (25 MHz)
        i_Clk         : in std_logic;

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

        -- PMOD based temp sensor
        io_PMOD_3 : inout std_logic ; -- SERIAL CLOCK - SCL
        io_PMOD_4 : inout std_logic ; -- SERIAl DATA - SDA

        o_LED_1 : inout std_logic;
        o_LED_2 : inout std_logic;
        o_LED_3 : inout std_logic;
        o_LED_4 : inout std_logic;

        i_UART_RX     : in std_logic;
        o_UART_TX     : out std_logic

    );
end entity DisplayTempOnSevenSegment;

architecture RTL of DisplayTempOnSevenSegment is
    signal r_TempInCelciusMSB       : std_logic_vector(7 downto 0);  --byte read from Temp sensor
    signal r_TempInCelciusLSB       : std_logic_vector(7 downto 0);  --byte read from Temp sensor
    signal r_TempInCelciusToDisplay : std_logic_vector(7 downto 0) := 0;
    signal r_TempReading_Ready      : std_logic := '0';  -- reading from Temp sensor is ready 

    signal r_StateForDebugging : integer range 0 to 99 := 0; --for debugging
    signal r_LastStateForDebugging : integer range 0 to 99 := 99; --for debugging
    signal r_StateChanged    : std_logic := '0';  
    signal r_StateAsByte     : std_logic_vector(7 downto 0);

    signal r_display_off : std_logic := '0';
    signal w_Segment1_A, w_Segment2_A : std_logic;
    signal w_Segment1_B, w_Segment2_B : std_logic;
    signal w_Segment1_C, w_Segment2_C : std_logic;
    signal w_Segment1_D, w_Segment2_D : std_logic;
    signal w_Segment1_E, w_Segment2_E : std_logic;
    signal w_Segment1_F, w_Segment2_F : std_logic;
    signal w_Segment1_G, w_Segment2_G : std_logic;

    -- to keep track for how many cycles we do NOT have a temprature reading so we can switch off display
    signal r_CountCyclesSinceNoTempReady : integer := 0 ;

    signal r_Uart_Tx_Active : std_logic := '0'; 
    signal r_UART_TX     : std_logic;

    signal r_SCL : std_logic := '0';
    signal r_SDA : std_logic := '0';
begin
    o_LED_2 <= '0';
    o_LED_3 <= '0';
    o_LED_4 <= '0';

    -- Instantiate Binary to 7-Segment Converter
    SevenSeg1_Inst : entity work.Binary_To_7Segment
        port map (
        i_Clk        => i_Clk,
        i_display_off => r_display_off,
        i_Binary_Num => r_TempInCelciusToDisplay(7 downto 4),
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
        i_display_off => r_display_off,
        i_Binary_Num => r_TempInCelciusToDisplay(3 downto 0),
        o_Segment_A  => w_Segment2_A,
        o_Segment_B  => w_Segment2_B,
        o_Segment_C  => w_Segment2_C,
        o_Segment_D  => w_Segment2_D,
        o_Segment_E  => w_Segment2_E,
        o_Segment_F  => w_Segment2_F,
        o_Segment_G  => w_Segment2_G
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


    -- instantiate UART sender
    Uart_Tx_Inst : entity work.Uart_Tx
        port map (
            i_Clk        => i_Clk,
            o_Uart_Serial_Tx    => r_UART_TX,
            o_Uart_Tx_Active => r_Uart_Tx_Active,
            i_Byte_To_Send => r_StateAsByte,
            i_Byte_Ready_To_send => r_StateChanged
    );
    o_UART_TX <= r_UART_TX   when r_Uart_Tx_Active = '1'  else '1';

    
    --Instantiate module to get temprature readings
    PModTMP3I2CTempSensor_Inst : entity work.PModTMP3I2CTempSensor
        -- generic map (
        --     g_CLKS_PER_BIT => 25000000/5 -- slown down for debugging
        -- )
        port map (
            i_Clk        => i_Clk,
            o_TempInCelciusMSB   => r_TempInCelciusMSB,
            o_TempInCelciusLSB   => r_TempInCelciusLSB,
            o_TempReading_Ready  => r_TempReading_Ready,
            o_I2CStateForDebugging  => r_StateForDebugging,
            io_SCL => r_SCL,
            io_SDA => r_SDA
    );
    io_PMOD_3 <= r_SCL;
    io_PMOD_4 <= r_SDA;

    -- track state changes just for debgging
    process_trackStateChange : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
          if r_StateForDebugging = r_LastStateForDebugging   then
                r_StateChanged <= '0';
           else
                r_StateChanged <= '1';
                o_LED_1 <= not o_LED_1;
                r_LastStateForDebugging <= r_StateForDebugging;

                if r_StateForDebugging >= 0 and r_StateForDebugging <= 9 then
                    r_StateAsByte <= std_logic_vector(to_unsigned(48 + r_StateForDebugging,r_StateAsByte'length));  -- 0-9
                elsif r_StateForDebugging > 9 and r_StateForDebugging <= 15 then
                    r_StateAsByte <= std_logic_vector(to_unsigned(65-10+r_StateForDebugging,r_StateAsByte'length));  -- A-F
                else
                    r_StateAsByte <= std_logic_vector(to_unsigned(63,r_StateAsByte'length));  -- '?'
                end if;
          end if;
        end if;
    end process process_trackStateChange;


     
    -- fetch the temp to be displayed     
    process_updateTempToDisplay : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            if r_TempReading_Ready = '1' then
                r_CountCyclesSinceNoTempReady <= 0;
          
                --convert to decimals
                r_TempInCelciusToDisplay(7 downto 4) <= std_logic_vector( to_unsigned((to_integer( unsigned(r_TempInCelciusMSB))) / 10 , 4) );
                r_TempInCelciusToDisplay(3 downto 0) <= std_logic_vector( to_unsigned((to_integer( unsigned(r_TempInCelciusMSB))) mod 10, 4) );

                r_display_off <= '0';
            else
                -- switch of display if no temprature for long time
                if r_CountCyclesSinceNoTempReady = 10000 then
                    r_display_off <= '1';
                    r_TempInCelciusToDisplay <= 0;
                end if;
                r_CountCyclesSinceNoTempReady <= r_CountCyclesSinceNoTempReady  + 1;
          end if;
        end if;
    end process process_updateTempToDisplay;

    

    
end architecture RTL;