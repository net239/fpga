library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

        I2C_DEVICE_TEMP_REGISTER: integer := 16#00# ; -- address of the register in device that stores the temprature

        -- Clocks per bit
        g_CLKS_PER_BIT : integer := 25000            -- Clock speed divided by rate  - 25,000,000 / 1,000
    );
    port (
        -- Main Clock - 25Mhz
        -- I2C standard speed is 100kbps, Fast Mode is 400Kbps and High Speed mode is 3.4Mbps
        i_Clk         : in std_logic;

        -- output temprature reading in Celcius - MSB and LSB bytes
        o_TempInCelciusMSB   : out std_logic_vector(7 downto 0);
        o_TempInCelciusLSB   : out std_logic_vector(7 downto 0);
        o_TempReading_Ready  : out std_logic;

        o_StateAsNumber             : out  integer range 0 to 32; --for debugging      

        io_SCL : inout std_logic ; -- SERIAL CLOCK - SCL
        io_SDA : inout std_logic  -- SERIAl DATA - SDA
    );
end entity PModTMP3I2CTempSensor;

architecture RTL of PModTMP3I2CTempSensor is

    --state machine to read data one bit at a time
    type    I2CReadingStateMachine is ( 
                state_PrepareStart, 
                state_Start_B1, state_Address_B1, state_WriteBit_B1, state_AckFromSlave_B1, 
                state_RegisterAddress_B2, state_AckFromSlave_B2, 
                state_Start_B3, state_Address_B3, state_ReadBit_B3, state_AckFromSlave_B3, 
                state_DataFromSlaveMSB,state_DataFromSlaveMSBAck,
                state_DataFromSlaveLSB,state_DataFromSlaveLSBAck
            );
    signal r_I2CReadingStateMachine : I2CReadingStateMachine := state_PrepareStart;
    signal r_StateAsNumber : integer range 0 to 32 := 0; --for debugging
    signal r_Clk_Count   : integer range 0 to g_CLKS_PER_BIT-1 := 0;

    signal r_AddrBit_Count   : integer range 0 to 7 := 0;
    signal r_Addr : std_logic_vector(7 downto 0);  --I2C expects MSB first
    signal r_TempRegisterAddr : std_logic_vector(7 downto 0);  --I2C expects MSB first
    signal r_DataFromSlaveBit_Count   : integer range 0 to 7 := 0;
    signal r_TempReading_Ready : std_logic := '0';
    
begin
    r_Addr <= std_logic_vector(to_unsigned(I2C_DEVICE_ADDRESS,r_Addr'length));
    r_TempRegisterAddr <= std_logic_vector(to_unsigned(I2C_DEVICE_TEMP_REGISTER,r_Addr'length));

    o_TempReading_Ready <= r_TempReading_Ready;
    r_StateAsNumber <= I2CReadingStateMachine'POS(r_I2CReadingStateMachine) ; 
    o_StateAsNumber <= r_StateAsNumber;
   
    
    -- Purpose: Control RX state machine
    process_I2C_RX : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            case r_I2CReadingStateMachine is
                when state_PrepareStart =>
                    -- lets first set SCL High and SDA High - We will later check if it remains high to make sure no one else is pulling it down
                    io_SCL <= '1'; 
                    io_SDA <= '1';
                    r_Clk_Count <= 0;
                    r_AddrBit_Count <= 0;
                    r_I2CReadingStateMachine <= state_Start_B1;
                when state_Start_B1 =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then
                        r_Clk_Count <= 0;    

                        --lets now set SDA Low ( While SCL is high) - this is the START condition
                        if io_SCL = '0' or io_SDA = '0' then
                            -- lets make sure no one else has pulled the lines low
                            -- looks like the bus is busy, lets try after some time
                            r_I2CReadingStateMachine <= state_PrepareStart;
                        else
                            --all good, lets send START condition
                            io_SDA <= '0';
                            r_I2CReadingStateMachine <= state_Address_B1;
                        end if;
                    else
                        io_SCL <= '1'; 
                        io_SDA <= '1';
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;
                when state_Address_B1 =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;

                        -- lets bring down clock so we can start changing data 
                        io_SCL <= '0'; 

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2  + ( g_CLKS_PER_BIT-1) / 4 then    
                        r_Clk_Count <= r_Clk_Count + 1;    

                        --send address bits MSB fist
                        -- so when r_AddrBit_Count is zero, we want to pick bit 7 ( since address in I2C is 7 bit)
                        io_SDA <= r_Addr(r_Addr'length - 2 - r_AddrBit_Count); --I2C expects MSB first

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) then    
                        r_Clk_Count <= 0;

                        -- clock UP to indicate data is stable
                        io_SCL <= '1'; 

                        if r_AddrBit_Count = (r_Addr'length - 2) then -- count only - 0,1,2,3,4,5,6 and then roll over                           
                            r_AddrBit_Count  <= 0;
                            r_I2CReadingStateMachine <= state_WriteBit_B1;
                        else
                            r_AddrBit_Count <= r_AddrBit_Count + 1;
                        end if;
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;
                when state_WriteBit_B1 =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    

                        -- lets bring down clock so we can start changing data
                        io_SCL <= '0'; 

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2  + ( g_CLKS_PER_BIT-1) / 4 then    
                        r_Clk_Count <= r_Clk_Count + 1;        

                        io_SDA <= '0'; -- Set this to W - Write as we are setting register pointer, 0 is write
                        
                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) then    
                        r_Clk_Count <= 0;    

                        -- clock UP to indicate data is stable
                        io_SCL <= '1'; 

                        r_I2CReadingStateMachine <= state_AckFromSlave_B1;        
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;    
                when state_AckFromSlave_B1 =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    
                        
                        -- lets bring down clock so we can start getting data
                        io_SCL <= '0'; 

                        

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2  + ( g_CLKS_PER_BIT-1) / 4 then    
                        r_Clk_Count <= r_Clk_Count + 1;        
                        
                        --release SDA so slave can write
                        io_SDA <= '1';

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) then    
                        r_Clk_Count <= 0;        

                        -- clock UP to indicate data is stable
                        io_SCL <= '1'; 

                        if io_SDA = '0' then
                            r_I2CReadingStateMachine <= state_RegisterAddress_B2;        
                        else
                            r_I2CReadingStateMachine <= state_PrepareStart;        -- restarting since we did not get ack
                        end if;
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;       
                when state_RegisterAddress_B2 =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;

                        -- lets bring down clock so we can start changing data 
                        io_SCL <= '0'; 

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2  + ( g_CLKS_PER_BIT-1) / 4 then    
                        r_Clk_Count <= r_Clk_Count + 1;    

                        --send address bits MSB fist
                        -- so when r_AddrBit_Count is zero, we want to pick bit 7 ( since address in I2C is 7 bit)
                        io_SDA <= r_TempRegisterAddr(r_TempRegisterAddr'length - 1 - r_AddrBit_Count); --I2C expects MSB first

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) then    
                        r_Clk_Count <= 0;

                        -- clock UP to indicate data is stable
                        io_SCL <= '1'; 

                        if r_AddrBit_Count = (r_TempRegisterAddr'length - 1) then -- count only - 0,1,2,3,4,5,6,7 and then roll over                           
                            r_AddrBit_Count  <= 0;
                            r_I2CReadingStateMachine <= state_AckFromSlave_B2;
                        else
                            r_AddrBit_Count <= r_AddrBit_Count + 1;
                        end if;
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;    
                when state_AckFromSlave_B2 =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    
                        
                        -- lets bring down clock so we can start getting data
                        io_SCL <= '0'; 

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2  + ( g_CLKS_PER_BIT-1) / 4 then    
                        r_Clk_Count <= r_Clk_Count + 1;        
                        
                        --release SDA so slave can write
                        io_SDA <= '1';


                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) then    
                        r_Clk_Count <= 0;        

                        -- clock UP to indicate data is stable
                        io_SCL <= '1'; 

                        if io_SDA = '0' then
                            r_I2CReadingStateMachine <= state_Start_B3;        
                        else
                            r_I2CReadingStateMachine <= state_PrepareStart;        -- restarting since we did not get ack
                        end if;
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;  
                when state_Start_B3 =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then
                        r_Clk_Count <= 0;    

                        --lets now set SDA Low ( While SCL is high) - this is the START condition
                        if io_SCL = '0' or io_SDA = '0' then
                            -- lets make sure no one else has pulled the lines low
                            -- looks like the bus is busy, lets try after some time
                            r_I2CReadingStateMachine <= state_PrepareStart;
                        else
                            --all good, lets send START condition
                            io_SDA <= '0';
                            r_I2CReadingStateMachine <= state_Address_B3;
                        end if;
                    else
                        io_SCL <= '1'; 
                        io_SDA <= '1';
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;
                when state_Address_B3 =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;

                        -- lets bring down clock so we can start changing data 
                        io_SCL <= '0'; 

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2  + ( g_CLKS_PER_BIT-1) / 4 then    
                        r_Clk_Count <= r_Clk_Count + 1;    

                        --send address bits MSB fist
                        -- so when r_AddrBit_Count is zero, we want to pick bit 7 ( since address in I2C is 7 bit)
                        io_SDA <= r_Addr(r_Addr'length - 2 - r_AddrBit_Count); --I2C expects MSB first

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) then    
                        r_Clk_Count <= 0;

                        -- clock UP to indicate data is stable
                        io_SCL <= '1'; 

                        if r_AddrBit_Count = (r_Addr'length - 2) then -- count only - 0,1,2,3,4,5,6 and then roll over                           
                            r_AddrBit_Count  <= 0;
                            r_I2CReadingStateMachine <= state_ReadBit_B3;
                        else
                            r_AddrBit_Count <= r_AddrBit_Count + 1;
                        end if;
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;
                when state_ReadBit_B3 =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    

                        -- lets bring down clock so we can start changing data
                        io_SCL <= '0'; 

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2  + ( g_CLKS_PER_BIT-1) / 4 then    
                        r_Clk_Count <= r_Clk_Count + 1;        

                        io_SDA <= '1'; -- Set this to R - Write as we are reading temprature 
                        
                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) then    
                        r_Clk_Count <= 0;    

                        -- clock UP to indicate data is stable
                        io_SCL <= '1'; 

                        r_I2CReadingStateMachine <= state_AckFromSlave_B3;        
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;    
                when state_AckFromSlave_B3 =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    
                        
                        -- lets bring down clock so we can start getting data
                        io_SCL <= '0'; 

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2  + ( g_CLKS_PER_BIT-1) / 4 then    
                        r_Clk_Count <= r_Clk_Count + 1;    
                        
                        --release SDA so slave can write
                        io_SDA <= '1';
                        

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) then    
                        r_Clk_Count <= 0;        

                        -- clock UP to indicate data is stable
                        io_SCL <= '1'; 

                        if io_SDA = '0' then
                            r_I2CReadingStateMachine <= state_DataFromSlaveMSB;        
                        else
                            r_I2CReadingStateMachine <= state_PrepareStart;        -- restarting since we did not get ack
                        end if;
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;                 
                when state_DataFromSlaveMSB =>
                    r_TempReading_Ready <= '0'; -- mark this as we are now reading the data

                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    
                        
                        -- lets bring down clock so we can start changing data
                        io_SCL <= '0';

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2  + ( g_CLKS_PER_BIT-1) / 4 then    
                        r_Clk_Count <= r_Clk_Count + 1;            

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) then    
                        r_Clk_Count <= 0;

                        -- clock UP to indicate data is stable
                        io_SCL <= '1'; 

                        if r_DataFromSlaveBit_Count < 7 then
                            --read data
                            o_TempInCelciusMSB(r_DataFromSlaveBit_Count) <= io_SDA;
                            r_DataFromSlaveBit_Count <= r_DataFromSlaveBit_Count + 1;
                        else
                            r_DataFromSlaveBit_Count  <= 0;
                            r_I2CReadingStateMachine <= state_DataFromSlaveMSBAck;
                        end if;    
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;       
                when state_DataFromSlaveMSBAck =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    
                        
                        -- lets bring down clock so we can start changing data
                        io_SCL <= '0';

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2  + ( g_CLKS_PER_BIT-1) / 4 then    
                        r_Clk_Count <= r_Clk_Count + 1;            

                        -- send ACk
                        io_SDA <= '0';

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) then    
                        r_Clk_Count <= 0;

                        -- clock UP to indicate data is stable
                        io_SCL <= '1'; 
                        
                        r_I2CReadingStateMachine <= state_DataFromSlaveLSB;  
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;             
                when state_DataFromSlaveLSB =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    
                        
                        -- lets bring down clock so we can start changing data
                        io_SCL <= '0';

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2  + ( g_CLKS_PER_BIT-1) / 4 then    
                        r_Clk_Count <= r_Clk_Count + 1;            
                        
                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) then    
                        r_Clk_Count <= 0;                        

                        -- clock UP to indicate data is stable
                        io_SCL <= '1'; 

                        if r_DataFromSlaveBit_Count < 7 then
                            --read data
                            o_TempInCelciusLSB(r_DataFromSlaveBit_Count) <= io_SDA;
                            r_DataFromSlaveBit_Count <= r_DataFromSlaveBit_Count + 1;
                        else
                            r_DataFromSlaveBit_Count  <= 0;
                            r_I2CReadingStateMachine <= state_DataFromSlaveLSBAck;
                        end if;    
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;  
                when state_DataFromSlaveLSBAck =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    
                        
                        -- lets bring down clock so we can start changing data
                        io_SCL <= '0';

                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2  + ( g_CLKS_PER_BIT-1) / 4 then    
                        r_Clk_Count <= r_Clk_Count + 1;            

                        --send ACk
                        io_SDA <= '1';

                        
                   elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) then    
                        r_Clk_Count <= 0;                         

                        
                        -- clock UP to indicate data is stable
                        io_SCL <= '1'; 
                        
                        r_I2CReadingStateMachine <= state_PrepareStart;  

                        --indicate we are done reading both bytes
                        r_TempReading_Ready <= '1';

                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;                                      
                when others =>
                    r_I2CReadingStateMachine <= state_PrepareStart;
            end case;
        end if;
    end process process_I2C_RX;

end architecture RTL;