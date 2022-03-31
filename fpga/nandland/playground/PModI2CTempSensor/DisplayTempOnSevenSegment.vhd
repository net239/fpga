library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
        io_PMOD_4 : inout std_logic;  -- SERIAl DATA - SDA

        io_PMOD_9 : inout std_logic ; -- SERIAL CLOCK - SCL
        io_PMOD_10 : inout std_logic;  -- SERIAl DATA - SDA


        --debugging
        o_LED_1 : inout std_logic;
        o_LED_2 : inout std_logic;
        o_LED_3 : inout std_logic;
        o_LED_4 : inout std_logic
    );
end entity DisplayTempOnSevenSegment;

architecture RTL of DisplayTempOnSevenSegment is
    signal r_TempInCelciusMSB     : std_logic_vector(7 downto 0);  --byte read from Temp sensor
    signal r_TempInCelciusLSB     : std_logic_vector(7 downto 0);  --byte read from Temp sensor
    signal r_TempInCelciusToDisplay : std_logic_vector(7 downto 0) := 0;
    signal r_TempReading_Ready    : std_logic := '0';  -- reading from Temp sensor is ready 
    signal r_GotAckFromSensor    : std_logic := '0';  -- Got some Ack from sensor - just for debuging
    signal r_IC2BusOk    : std_logic := '0';
    signal r_StateAsNumber : integer range 0 to 32 := 0; --for debugging

    signal r_ClockCounter :  integer := 0; -- to generate a slow clock
    signal i_SlowClock    : std_logic := '0';

    signal w_Segment1_A, w_Segment2_A : std_logic;
    signal w_Segment1_B, w_Segment2_B : std_logic;
    signal w_Segment1_C, w_Segment2_C : std_logic;
    signal w_Segment1_D, w_Segment2_D : std_logic;
    signal w_Segment1_E, w_Segment2_E : std_logic;
    signal w_Segment1_F, w_Segment2_F : std_logic;
    signal w_Segment1_G, w_Segment2_G : std_logic;
begin
    -- Instantiate Binary to 7-Segment Converter
    SevenSeg1_Inst : entity work.Binary_To_7Segment
        port map (
        i_Clk        => i_Clk,
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
        i_Binary_Num => r_TempInCelciusToDisplay(3 downto 0),
        o_Segment_A  => w_Segment2_A,
        o_Segment_B  => w_Segment2_B,
        o_Segment_C  => w_Segment2_C,
        o_Segment_D  => w_Segment2_D,
        o_Segment_E  => w_Segment2_E,
        o_Segment_F  => w_Segment2_F,
        o_Segment_G  => w_Segment2_G
    );
    
    --Instantiate module to get temprature readings
    PModTMP3I2CTempSensor_Inst : entity work.PModTMP3I2CTempSensor
        generic map (
            g_CLKS_PER_BIT => 5
        )
        port map (
            i_Clk        => i_SlowClock,
            o_TempInCelciusMSB   => r_TempInCelciusMSB,
            o_TempInCelciusLSB   => r_TempInCelciusLSB,
            o_TempReading_Ready  => r_TempReading_Ready,
            o_StateAsNumber  => r_StateAsNumber,
            io_SCL => io_PMOD_3,
            io_SDA => io_PMOD_4
    );

    --slow down clock
    process_slowClock  : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            if r_ClockCounter = 25000000 then
                i_SlowClock <= '1';
                r_ClockCounter <= 0;
            else
                r_ClockCounter <= r_ClockCounter  + 1;
                i_SlowClock <= '0';
            end if;
        end if;
    end process process_slowClock;

     -- fetch the temp to be displayed     
     process_updateTempToDisplay : process (i_SlowClock)
     begin
         if rising_edge(i_SlowClock) then
           if r_TempReading_Ready = '1' then
                --r_TempInCelciusToDisplay <= 2;
                o_LED_2 <= '0';
                o_LED_1 <= '0';
            else
                --r_TempInCelciusToDisplay <= 1;
                o_LED_2 <= '1';
                o_LED_1 <= '1';
           end if;
         end if;
     end process process_updateTempToDisplay;

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

    r_TempInCelciusToDisplay <= std_logic_vector(to_unsigned(r_StateAsNumber,r_TempInCelciusToDisplay'length));

    io_PMOD_9 <= io_PMOD_3;
    io_PMOD_10 <= io_PMOD_4;

    o_LED_3 <= io_PMOD_3;
    o_LED_4 <= io_PMOD_4;



end architecture RTL;