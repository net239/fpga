library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- UART receiver 
entity Uart_Rx is
    generic (
        -- Clocks per bit
        g_CLKS_PER_BIT : integer := 217            -- Clock speed divided by baud rate  - 25,000,000 / 115,200
    );
    port (
        -- Main Clock (25 MHz)
        i_Clk         : in std_logic;

        -- input serial wire - 1 bit at a time
        i_Uart_Serial_Rx     : in std_logic;

        --output byte and a flag to indicate when its ready
        o_Byte_Read   : out std_logic_vector(7 downto 0);
        o_Byte_Ready  : out std_logic
    );
end entity Uart_Rx;

architecture RTL of UART_RX is

    --state machine to read data one bit at a time
    type    UartReadingStateMachine is ( 
                state_Idle, state_RX_Start_Bit, state_RX_Data_Bits, state_RX_Stop_Bit, state_Cleanup
            );
    signal r_UartReadingStateMachine : UartReadingStateMachine := state_Idle;
    
    signal r_Clk_Count   : integer range 0 to g_CLKS_PER_BIT-1 := 0;
    signal r_Bit_Index   : integer range 0 to 7 := 0;  -- 8 Bits Total
    signal r_Byte_Read   : std_logic_vector(7 downto 0) := (others => '0');
    signal r_Byte_Ready  : std_logic := '0';
begin
    -- Purpose: Control RX state machine
    process_UART_RX : process (i_Clk)
    begin
    if rising_edge(i_Clk) then
       
        case r_UartReadingStateMachine is
        when state_Idle =>
            r_Byte_Ready <= '0';
            r_Bit_Index  <= 0;
            r_Clk_Count  <= 0;

            if i_Uart_Serial_Rx = '0' then --got start bit
                r_UartReadingStateMachine <= state_RX_Start_Bit;
            else
                r_UartReadingStateMachine <= state_Idle;
            end if;
        when state_RX_Start_Bit =>
            if r_Clk_Count = ( g_CLKS_PER_BIT-1) / 2 then
                -- we have now reached middle of the bit, lets see if we are still low
                if i_Uart_Serial_Rx = '0' then
                    -- reset counter, this is the place we read from middle of bit, next middle will happen after g_CLKS_PER_BIT
                    r_Clk_Count <= 0;
                    -- good we are still low, lets move to next state of reading actual data
                    r_UartReadingStateMachine <= state_RX_Data_Bits;
                else
                    --problem, we became high here? lets go back Idle 
                    r_UartReadingStateMachine <= state_Idle;
                end if;
            else
                -- lets keep incrementing and wait to reach middle of bit
                r_Clk_Count <= r_Clk_Count + 1;
                r_UartReadingStateMachine <= state_RX_Start_Bit;
            end if;
        when state_RX_Data_Bits =>
            if r_Clk_Count = ( g_CLKS_PER_BIT-1)  then
                r_Clk_Count <= 0;
                r_Byte_Read(r_Bit_Index) <= i_Uart_Serial_Rx;

                -- see if we read all bits
                if r_Bit_Index = 7 then
                    r_Bit_Index <= 0;
                    r_UartReadingStateMachine <= state_RX_Stop_Bit;
                else 
                    r_Bit_Index <= r_Bit_Index + 1;
                    r_UartReadingStateMachine <= state_RX_Data_Bits;
                end if;
            else
                r_Clk_Count <= r_Clk_Count + 1;
                r_UartReadingStateMachine <= state_RX_Data_Bits;
            end if;
        when state_RX_Stop_Bit =>
            if r_Clk_Count = ( g_CLKS_PER_BIT-1)  then        
                  -- middle of stop bit  
                  -- mark the byte ready to use
                  r_Byte_Ready <= '1';

                  r_Clk_Count <= 0;
                  r_UartReadingStateMachine <= state_Cleanup;
            else
                r_Clk_Count <= r_Clk_Count + 1;
                r_UartReadingStateMachine <= state_RX_Stop_Bit;    
            end if;
        when state_Cleanup =>
            -- lets go back, start waiting for fresh data
            r_UartReadingStateMachine <= state_Idle;
            r_Byte_Ready   <= '0';
        when others =>
            r_UartReadingStateMachine <= state_Idle;
        end case;
    end if;
    end process process_UART_RX;

    o_Byte_Read  <= r_Byte_Read;
    o_Byte_Ready <= r_Byte_Ready;
end architecture RTL;