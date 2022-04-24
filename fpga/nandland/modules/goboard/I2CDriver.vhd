library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.I2CDriver_pkg.all;

-- Basic I2C driver interface
-- refer for I2C protocol - https://www.circuitbasics.com/basics-of-the-i2c-communication-protocol/
-- refer I2 Specs - https://i2c.info/i2c-bus-specification
-- refer more i2c - https://www.ti.com/lit/an/slva704/slva704.pdf
-- refer https://interrupt.memfault.com/blog/i2c-in-a-nutshell
entity I2CDriver is
    generic (
        I2C_DEVICE_ADDRESS: integer := 16#4F# ; -- hexadeciaml 0x48 - if JP1/JP2/JP3 all are set to GND the address for this PMOD sensor is 0x48. 7 BIT address

        -- Clocks per bit
        -- The i_Clk clock provided by this will be counted g_CLKS_PER_BIT times to generate one bit of information on I2C. - to drive io_SCL Clock
        -- I2C standard speed is 100kbps, Fast Mode is 400Kbps and High Speed mode is 3.4Mbps
        g_CLKS_PER_BIT : integer := 52500            
       
    );
    port (
        -- Main Clock - 25Mhz
        
        i_Clk         : in std_logic;

        -- read or write operation to be performed next
        i_ReadOrWriteOperation : in work.I2CDriver_pkg.t_Request_Type;

        -- if read operation, number of bytes to read
        i_NumBytesToread : in integer range 1 to 16;

        -- if write operation, this is the byte to write
        i_ByteToWrite : in std_logic_vector(7 downto 0);

        -- byte read from last read operation
        o_ByteRead  :  out std_logic_vector(7 downto 0);
        o_ByteReady :  out std_logic;

        -- Write or Read operation Stage 0 - Working, 1 - Completed Success, 2 - Completed Error
        o_Request_Completion_State :  out work.I2CDriver_pkg.t_Request_State;


        o_StateAsNumber             : out  integer range 0 to 32; --for debugging      

        io_SCL : inout std_logic ; -- SERIAL CLOCK - SCL
        io_SDA : inout std_logic  -- SERIAl DATA - SDA
    );
end entity I2CDriver;

architecture RTL of I2CDriver is

    --state machine to read data one bit at a time
    type    t_I2C_State is ( 
                IDLE, 
                START, 
                ADDRESS,
                SET_WRITE_BIT,
                WAIT_ACK,
                CHECK_ACK,
                WRITE_DATA, 
                IDLE_AFTER_BIT_COMPLETION
            );
    signal r_I2C_State : t_I2C_State := IDLE;

    signal r_SDA: std_logic := '1';
    signal r_SCL: std_logic := '1';

    signal r_ReadingOrWtiting: work.I2CDriver_pkg.t_Request_Type;
    signal r_ByteToWrite :  std_logic_vector(7 downto 0);

    signal r_Clk_Count   : integer range 0 to g_CLKS_PER_BIT-1 := 0;
    

    signal r_Addr : std_logic_vector(7 downto 0);  --I2C expects MSB first
    signal r_DataToSlaveBit_Count   : integer range 0 to 7 := 0;
    signal r_DataFromSlaveBit_Count   : integer range 0 to 7 := 0;
    
begin
    r_Addr <= std_logic_vector(to_unsigned(I2C_DEVICE_ADDRESS,r_Addr'length));
    o_StateAsNumber <= t_I2C_State'POS(r_I2C_State) ; 
   
    -- process to generate clock signal for slave
    generate_SCL : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            if r_Clk_Count = g_CLKS_PER_BIT -1 then
                r_SCL <= not r_SCL;
                r_Clk_Count <= 0;
            else
                r_Clk_Count <= r_Clk_Count + 1;
            end if;
        end if;
    end process generate_SCL;

    process_I2C : process (i_Clk)
    begin
        if rising_edge(i_Clk) then
            case r_I2C_State is
                when IDLE =>
                    if i_ReadOrWriteOperation = work.I2CDriver_pkg.WRITE then -- write
                        r_ReadingOrWtiting <= work.I2CDriver_pkg.WRITE;
                        r_ByteToWrite <= i_ByteToWrite;

                        r_I2C_State <= START;
                        o_Request_Completion_State <=  work.I2CDriver_pkg.WORKING;

                    elsif i_ReadOrWriteOperation = work.I2CDriver_pkg.READ then -- read
                        r_ReadingOrWtiting <= work.I2CDriver_pkg.READ;

                        r_I2C_State <= START;
                        o_Request_Completion_State <=  work.I2CDriver_pkg.WORKING;

                    else
                        o_Request_Completion_State <=  work.I2CDriver_pkg.IDLE;

                    end if;
                when START =>
                    r_DataToSlaveBit_Count <= 0;
                    r_DataFromSlaveBit_Count <= 0;

                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 4 then
                         r_SDA <= '1'; -- set SDA high so we can pull it low and generate START condition
                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then

                         --middle of bit, lets pull SDA low when SCL is High - Start condition of I2C Protocol
                         if  r_SCL = '1' then
                            if r_SDA = '0' then
                                --someone else is pulling SDA low?
                                r_I2C_State <= IDLE_AFTER_BIT_COMPLETION;
                                o_Request_Completion_State <=  work.I2CDriver_pkg.COMPLETED_ERROR;
                            else
                                r_SDA <= '0';
                                r_I2C_State <= ADDRESS;
                            end if;
                         end if;
                    end if;
                when ADDRESS =>
                    -- transmit address      
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then 
                        if  r_SCL = '0' then -- change data only when SCL is low
                            
                            --send address bits MSB fist
                            -- so when r_AddrBit_Count is zero, we want to pick bit 7 ( since address in I2C is 7 bit)
                            r_SDA <= r_Addr(r_Addr'length - 2 - r_DataToSlaveBit_Count); --I2C expects MSB first

                            if r_DataToSlaveBit_Count = (r_Addr'length - 2) then -- count only - 0,1,2,3,4,5,6 and then roll over                           
                                r_DataToSlaveBit_Count  <= 0;
                                r_I2C_State <= SET_WRITE_BIT;
                            else
                                r_DataToSlaveBit_Count <= r_DataToSlaveBit_Count + 1;
                            end if;
                        end if;
                    end if;
                when SET_WRITE_BIT =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then 
                        if  r_SCL = '0' then -- change data only when SCL is low
                            r_SDA <= '0'; -- Set this to 0 - Write
                            r_I2C_State <= WAIT_ACK;
                        end if;
                    end if;
                when WAIT_ACK =>
                    if r_Clk_Count =  0 then          
                        if  r_SCL = '0' then 
                            r_SDA <= '1' ; --set SDA High so we can let slave bring it down
                        end if;
                    elsif r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then 
                        if  r_SCL = '0' then 
                            r_I2C_State <= CHECK_ACK;
                        end if;    
                    end if;    
                when CHECK_ACK =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then 
                        if  r_SCL = '1' then 
                            if r_SDA = '0' then
                                r_DataToSlaveBit_Count  <= 0;
                                r_I2C_State <= WRITE_DATA;
                            else
                                -- did not get ACK ??
                                r_I2C_State <= IDLE_AFTER_BIT_COMPLETION;
                                o_Request_Completion_State <=  work.I2CDriver_pkg.COMPLETED_ERROR;
                            end if;
                        end if;
                    end if;    
                when WRITE_DATA =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then 
                        if  r_SCL = '0' then 
                             --send  bits MSB fist
                            -- so when r_DataToSlaveBit_Count is zero, we want to pick bit 8 
                            r_SDA <= r_ByteToWrite(r_ByteToWrite'length - 1 - r_DataToSlaveBit_Count); --I2C expects MSB first

                            if r_DataToSlaveBit_Count = (r_ByteToWrite'length - 1) then -- count only - 0,1,2,3,4,5,6,7 and then roll over                           
                                r_DataToSlaveBit_Count  <= 0;
                                r_I2C_State <= IDLE_AFTER_BIT_COMPLETION;
                            else
                                r_DataToSlaveBit_Count <= r_DataToSlaveBit_Count + 1;
                            end if;
                        end if;
                    end if;    
                when IDLE_AFTER_BIT_COMPLETION =>
                    if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then 
                        if  r_SCL = '0' then 
                            r_I2C_State <= IDLE;
                        end if;
                    end if;    
                    
                when others =>
                    r_I2C_State <= r_I2C_State;            
            end case;
        end if;
    end process process_I2C;

    -- output clock only when we are not in idle state
    io_SCL <= 'Z' when r_I2C_State = IDLE else r_SCL;
    io_SDA <= 'Z' when r_I2C_State = IDLE else r_SDA;

end architecture RTL;