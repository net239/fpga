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
-- NOTE This design is a single Master implementation - it assumes that there is only one master on the IC2 bus
entity PModTMP3I2CTempSensor is
    generic (
        I2C_DEVICE_ADDRESS: integer := 16#48# ; -- hexadeciaml 0x48 - if JP1/JP2/JP3 all are set to GND the address for this PMOD sensor is 0x48. 7 BIT address

        -- Clocks per bit
        g_CLKS_PER_BIT : integer := 250            -- Clock speed divided by baud rate  - 25,000,000 / 100,000
    );
    port (
        -- Main Clock - 
        -- I2C standard speed is 100kbps, Fast Mode is 400Kbps and High Speed mode is 3.4Mbps
        i_Clk         : in std_logic;

        -- output temprature reading in Celcius - MSP and LCB bytes
        o_TempInCelciusMSB   : out std_logic_vector(7 downto 0);
        o_TempInCelciusLSB   : out std_logic_vector(7 downto 0);
        o_TempReading_Ready  : out std_logic;

        io_PMOD_3 : out std_logic ; -- SERIAL CLOCK - SCL
        io_PMOD_4 : out std_logic  -- SERIAl DATA - SDA
    );
end entity PModTMP3I2CTempSensor;

architecture RTL of PModTMP3I2CTempSensor is

    --state machine to read data one bit at a time
    type    I2CReadingStateMachine is ( 
                state_PrepareStart, state_Start, state_Address, state_Address, state_ReadWriteBit, state_AckFromSlave, state_DataFromSlaveMSB,state_DataFromSlaveMSBAck,state_DataFromSlaveLSB,state_DataFromSlaveLSBAck
            );
    signal r_I2CReadingStateMachine : I2CReadingStateMachine := state_PrepareStart;
    signal r_Clk_Count   : integer range 0 to g_CLKS_PER_BIT-1 := 0;

    signal r_AddrBit_Count   : integer range 0 to 7 := 0;
    signal r_DataFromSaleBit_Count   : integer range 0 to 7 := 0;
    signal w_SDA :  std_logic := '1';
    signal w_SCL :  std_logic := '1';
begin
    -- Purpose: Control RX state machine
    process_I2C_RX : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            case r_I2CReadingStateMachine is
                when state_PrepareStart =>
                    -- lets first set SCL High and SDA High
                    -- TODO - This should be changed for multiple master setup
                    w_SCL <= '1'; 
                    w_SDA <= '1';
                    r_Clk_Count <= 0;
                    r_I2CReadingStateMachine <= state_Start;
                when state_Start =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then
                        r_Clk_Count <= 0;

                        --lets now set SDA Low ( While SCL is high) - this is the START condition
                        w_SDA <= '0';
                        r_I2CReadingStateMachine <= state_Address;
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;
                when state_Address =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;

                        -- lets bring down clock so we can start changing data 
                        w_SCL <= '0'; 
                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1)  then
                        r_Clk_Count <= 0;

                        if r_AddrBit_Count < 7 then
                            --send address bits
                            w_SDA <= std_logic_vector(to_unsigned(I2C_DEVICE_ADDRESS,7))(r_AddrBit_Count);
                            r_AddrBit_Count <= r_AddrBit_Count + 1;
                        else
                            r_AddrBit_Count  <= 0;
                            r_I2CReadingStateMachine <= state_ReadWriteBit;
                        end if;

                        -- clock UP to indicate data is stable
                        w_SCL <= '1'; 
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;
                when state_ReadWriteBit =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    

                        -- lets bring down clock so we can start changing data
                        w_SCL <= '0'; 
                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1)  then
                        r_Clk_Count <= 0;

                        w_SDA <= '1'; -- We are requesting the slave ( the temp sensor)   to send us data
                        r_I2CReadingStateMachine <= state_AckFromSlave;        

                        -- clock UP to indicate data is stable
                        w_SCL <= '1'; 
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;    
                when state_AckFromSlave =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    
                        
                        -- lets bring down clock so we can start changing data
                        w_SCL <= '0';
                        
                        --lets pull back so slave can send us ACK
                        w_SDA <= '1';

                        r_Clk_Count <= r_Clk_Count + 1;
                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1)  then
                        r_Clk_Count <= 0;

                        if W_SDA = '0' then
                            r_I2CReadingStateMachine <= state_DataFromSlaveMSB;        
                        else
                            r_I2CReadingStateMachine <= state_PrepareStart;        -- restarting since we did not get ack
                        end if;
                        
                        -- clock UP to indicate data is stable
                        w_SCL <= '1'; 
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;       
                when state_DataFromSlaveMSB =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    
                        
                        -- lets bring down clock so we can start changing data
                        w_SCL <= '0';
                        
                        r_Clk_Count <= r_Clk_Count + 1;
                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1)  then
                        r_Clk_Count <= 0;

                        if r_DataFromSaleBit_Count < 7 then
                            --read data
                            o_TempInCelciusMSB(r_DataFromSaleBit_Count) <= w_SDA;
                            r_DataFromSaleBit_Count <= r_DataFromSaleBit_Count + 1;
                        else
                            r_DataFromSaleBit_Count  <= 0;
                            r_I2CReadingStateMachine <= state_DataFromSlaveMSBAck;
                        end if;    

                        -- clock UP to indicate data is stable
                        w_SCL <= '1'; 
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;       
                when state_DataFromSlaveMSBAck =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    
                        
                        -- lets bring down clock so we can start changing data
                        w_SCL <= '0';
                        
                        r_Clk_Count <= r_Clk_Count + 1;
                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1)  then
                        r_Clk_Count <= 0;

                        W_SDA <= '0';

                        -- clock UP to indicate data is stable
                        w_SCL <= '1'; 
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;             
                when state_DataFromSlaveLSB =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    
                        
                        -- lets bring down clock so we can start changing data
                        w_SCL <= '0';
                        
                        r_Clk_Count <= r_Clk_Count + 1;
                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1)  then
                        r_Clk_Count <= 0;

                        if r_DataFromSaleBit_Count < 7 then
                            --read data
                            o_TempInCelciusLSB(r_DataFromSaleBit_Count) <= w_SDA;
                            r_DataFromSaleBit_Count <= r_DataFromSaleBit_Count + 1;
                        else
                            r_DataFromSaleBit_Count  <= 0;
                            r_I2CReadingStateMachine <= state_DataFromSlaveLSBAck;
                        end if;    
                                            
                        -- clock UP to indicate data is stable
                        w_SCL <= '1'; 
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;  
                when state_DataFromSlaveLSBAck =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then    
                        r_Clk_Count <= r_Clk_Count + 1;    
                        
                        -- lets bring down clock so we can start changing data
                        w_SCL <= '0';
                        
                        r_Clk_Count <= r_Clk_Count + 1;
                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1)  then
                        r_Clk_Count <= 0;

                        W_SDA <= '0';
                                            
                        -- clock UP to indicate data is stable
                        w_SCL <= '1'; 
                    else
                        r_Clk_Count <= r_Clk_Count + 1;
                    end if;                                      
                when others =>
                    r_I2CReadingStateMachine <= state_PrepareStart;
            end case;
        end if;
    end process process_I2C_RX;

    io_PMOD_4 <= w_SDA;
    io_PMOD_3 <= w_SCL;

end architecture RTL;