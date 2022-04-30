library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.I2CDriver_pkg.all;

-- read temprature from Digilent Pmod TMP3 Temprature sensor
-- refer https://digilent.com/reference/pmod/pmodtmp3/reference-manual
-- refer for I2C protocol - https://www.circuitbasics.com/basics-of-the-i2c-communication-protocol/
-- refer I2 Specs - https://i2c.info/i2c-bus-specification
-- refer for Pmod specs https://digilent.com/reference/_media/reference/pmod/pmod-interface-specification-1_2_0.pdf
-- refer for temp sensor details - https://ww1.microchip.com/downloads/en/DeviceDoc/21935D.pdf
-- refer Quick Start operation : https://digilent.com/reference/_media/reference/pmod/pmodtmp3/pmodtmp3_rm.pdf
-- refer more i2c - https://www.ti.com/lit/an/slva704/slva704.pdf
-- refer https://interrupt.memfault.com/blog/i2c-in-a-nutshell
-- refer Page 17 https://ww1.microchip.com/downloads/en/DeviceDoc/21935D.pdf
entity PModTMP3I2CTempSensor is
    generic (
        I2C_DEVICE_ADDRESS: integer := 16#4F# ; -- hexadeciaml 0x48 - if JP1/JP2/JP3 all are set to GND the address for this PMOD sensor is 0x48. 7 BIT address

        I2C_DEVICE_TEMP_REGISTER: integer := 16#0# ; -- address of the register in device that stores the temprature

        -- Clocks per bit
        -- The i_Clk clock provided by this will be counted g_CLKS_PER_BIT times to generate one bit of information on I2C. - to drive io_SCL Clock
        -- I2C standard speed is 100kbps, Fast Mode is 400Kbps and High Speed mode is 3.4Mbps
        g_CLKS_PER_BIT : integer := 251            -- Clock speed divided by rate  - 25,000,000 / 100000
    );
    port (
        -- Main Clock - 25Mhz
        -- I2C standard speed is 100kbps, Fast Mode is 400Kbps and High Speed mode is 3.4Mbps
        i_Clk         : in std_logic;

        -- output temprature reading in Celcius - MSB and LSB bytes
        o_TempInCelciusMSB   : out std_logic_vector(7 downto 0);
        o_TempInCelciusLSB   : out std_logic_vector(7 downto 0);
        o_TempReading_Ready  : out std_logic;

        o_I2CStateForDebugging             : out  integer range 0 to 32; --for debugging      

        io_SCL : inout std_logic ; -- SERIAL CLOCK - SCL
        io_SDA : inout std_logic  -- SERIAl DATA - SDA
    );
end entity PModTMP3I2CTempSensor;

architecture RTL of PModTMP3I2CTempSensor is
    signal r_ReadOrWriteOperation: work.I2CDriver_pkg.t_Request_Type := work.I2CDriver_pkg.IDLE; -- un initialized
    signal r_NumBytesToread : integer range 1 to 16;
    signal r_TempReading_Ready  :  std_logic := '0';

    signal r_I2CByteRead  :  std_logic_vector(7 downto 0);
    signal r_I2CByteReady :  std_logic;
    signal r_I2CByteToWrite  :  std_logic_vector(7 downto 0);

    signal r_I2CRequest_Completion_State :   work.I2CDriver_pkg.t_Request_State;
    signal r_I2CAddr : std_logic_vector(6 downto 0);  --I2C expects MSB first

    signal r_I2CStateForDebugging          :   integer range 0 to 32; --for debugging      

    type    t_State is ( 
                IDLE, 
                WRITE_REG_ADDRESS, -- register address that stores temprature, write this address to output
                WAIT_WRITE_ACK, 
                READ_MSB,
                WAIT_READ_MSB_ACK,
                WAIT_READ_LSB_ACK
            );
    signal r_State : t_State := IDLE;
begin

    r_I2CAddr <= std_logic_vector(to_unsigned(I2C_DEVICE_ADDRESS,r_I2CAddr'length));
    o_I2CStateForDebugging <= r_I2CStateForDebugging ; 
    o_TempReading_Ready <= r_TempReading_Ready;

     --Instantiate module to get temprature readings
     I2CDriver_Inst : entity work.I2CDriver
     generic map (
        g_CLKS_PER_BIT => g_CLKS_PER_BIT,
        I2C_DEVICE_ADDRESS => I2C_DEVICE_ADDRESS
     )
     port map (
         i_Clk        => i_Clk,
         i_ReadOrWriteOperation   => r_ReadOrWriteOperation,
         o_StateForDebugging  => r_I2CStateForDebugging,
         i_NumBytesToread => r_NumBytesToread,
         i_ByteToWrite => r_I2CByteToWrite,
         o_ByteRead => r_I2CByteRead,
         o_ByteReady => r_I2CByteReady,
         o_Request_Completion_State => r_I2CRequest_Completion_State,
         io_SCL => io_SCL,
         io_SDA => io_SDA
    );

    process_I2CTempSensor : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            case r_State is
                when IDLE =>
                    r_TempReading_Ready <= '0';
                    r_ReadOrWriteOperation <= work.I2CDriver_pkg.IDLE;
                    r_State <= WRITE_REG_ADDRESS;

                when WRITE_REG_ADDRESS =>
                    r_I2CByteToWrite <= std_logic_vector(to_unsigned(I2C_DEVICE_TEMP_REGISTER,r_I2CByteToWrite'length));
                    r_ReadOrWriteOperation <= work.I2CDriver_pkg.WRITE;  
                    r_State <= WAIT_WRITE_ACK;
                when WAIT_WRITE_ACK =>
                    if r_I2CRequest_Completion_State = work.I2CDriver_pkg.COMPLETED_OK then
                        r_ReadOrWriteOperation <= work.I2CDriver_pkg.IDLE;
                        r_State <= READ_MSB;
                    elsif r_I2CRequest_Completion_State = work.I2CDriver_pkg.COMPLETED_ERROR then
                        r_ReadOrWriteOperation <= work.I2CDriver_pkg.IDLE;
                        r_State <= IDLE;    
                    end if;
                when READ_MSB =>
                    if r_I2CRequest_Completion_State = work.I2CDriver_pkg.IDLE then    
                        r_NumBytesToread <= 2;
                        r_ReadOrWriteOperation <= work.I2CDriver_pkg.READ;  
                        r_State <= WAIT_READ_MSB_ACK;
                    end if;
                when WAIT_READ_MSB_ACK =>
                    if  r_I2CRequest_Completion_State /= work.I2CDriver_pkg.COMPLETED_ERROR then
                        if r_I2CByteReady = '1' then
                            o_TempInCelciusMSB <= r_I2CByteRead;
                            r_State <= WAIT_READ_LSB_ACK;
                        else 
                            r_TempReading_Ready <= '0';
                            r_State <= WAIT_READ_MSB_ACK;
                        end if;
                    else
                        r_ReadOrWriteOperation <= work.I2CDriver_pkg.IDLE;    
                        r_State <= IDLE;            
                    end if;
                when WAIT_READ_LSB_ACK =>
                    if  r_I2CRequest_Completion_State /= work.I2CDriver_pkg.COMPLETED_ERROR then
                        if r_I2CByteReady = '1' then    
                            o_TempInCelciusLSB <= r_I2CByteRead;
                            r_TempReading_Ready <= '1';
                            r_ReadOrWriteOperation <= work.I2CDriver_pkg.IDLE;    
                            r_State <= IDLE;
                        else
                            r_TempReading_Ready <= '0';
                            r_State <= WAIT_READ_LSB_ACK;
                        end if;
                    else
                        r_ReadOrWriteOperation <= work.I2CDriver_pkg.IDLE;    
                        r_State <= IDLE;    
                    end if;
                when others =>
                    r_State <= IDLE;    
            end case;
        end if;
    end process process_I2CTempSensor;

  

end architecture RTL;