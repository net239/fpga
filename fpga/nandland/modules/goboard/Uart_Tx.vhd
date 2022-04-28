library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- UART sender
entity Uart_Tx is
    generic (
        -- Clocks per bit
        g_CLKS_PER_BIT : integer := 217            -- Clock speed divided by baud rate  - 25,000,000 / 115,200
    );
    port (
        -- Main Clock (25 MHz)
        i_Clk         : in std_logic;

        -- output serial wire - 1 bit at a time
        o_Uart_Serial_Tx     : out std_logic;

        -- sending is active
        o_Uart_Tx_Active : out std_logic;

        --input byte 
        i_Byte_To_Send   : in std_logic_vector(7 downto 0);

        --- is byte ready to send
        i_Byte_Ready_To_send : in std_logic
    );
end entity Uart_Tx;

architecture RTL of Uart_Tx is

    --state machine to read data one bit at a time
    type    UartReadingStateMachine is ( 
                state_Idle, state_TX_Start_Bit, state_TX_Data_Bits, state_TX_Stop_Bit, state_Cleanup
            );
    signal r_UartReadingStateMachine : UartReadingStateMachine := state_Idle;
    
    signal r_Clk_Count   : integer range 0 to g_CLKS_PER_BIT-1 := 0;
    signal r_Bit_Index   : integer range 0 to 7 := 0;  -- 8 Bits Total;
    signal r_Byte_To_Send   :  std_logic_vector(7 downto 0);
begin
    -- Purpose: Control RX state machine
    process_UART_TX : process (i_Clk)
    begin
    if rising_edge(i_Clk) then
       
        case r_UartReadingStateMachine is
        when state_Idle =>
            o_Uart_Tx_Active <= '0';
            r_Clk_Count <= 0;
            o_Uart_Serial_Tx <= '1';
            r_Bit_Index  <= 0;

            if i_Byte_Ready_To_send ='1'  then
                r_Byte_To_Send <= i_Byte_To_Send; -- lets keep a copy of byte, just in case the input changes
                r_UartReadingStateMachine <= state_TX_Start_Bit;
            else
                r_UartReadingStateMachine <= state_Idle;
            end if;
           
        when state_TX_Start_Bit =>
            o_Uart_Tx_Active <= '1';
            
            -- Send start Bit
            o_Uart_Serial_Tx <= '0';

            if r_Clk_Count = ( g_CLKS_PER_BIT-1)  then
                r_Clk_Count <= 0;
                r_UartReadingStateMachine <= state_TX_Data_Bits;
            else
                r_Clk_Count <= r_Clk_Count + 1;
                r_UartReadingStateMachine <= state_TX_Start_Bit;
            end if;

        when state_TX_Data_Bits =>

            o_Uart_Serial_Tx <= r_Byte_To_Send(r_Bit_Index);
    
            if r_Clk_Count = ( g_CLKS_PER_BIT-1)  then
                r_Clk_Count <= 0;
                
                -- see if we sent all bits
                if r_Bit_Index = 7 then
                    r_Bit_Index <= 0;
                    r_UartReadingStateMachine <= state_TX_Stop_Bit;
                else 
                    r_Bit_Index <= r_Bit_Index + 1;
                    r_UartReadingStateMachine <= state_TX_Data_Bits;
                end if;
            else
                r_Clk_Count <= r_Clk_Count + 1;
                r_UartReadingStateMachine <= state_TX_Data_Bits;
            end if;
        when state_TX_Stop_Bit =>
            o_Uart_Serial_Tx <= '1';

            if r_Clk_Count = ( g_CLKS_PER_BIT-1)  then        
                r_Clk_Count <= 0;
                r_UartReadingStateMachine <= state_Cleanup;
            else
                r_Clk_Count <= r_Clk_Count + 1;
                r_UartReadingStateMachine <= state_TX_Stop_Bit;    
            end if;
        when state_Cleanup =>
            -- lets go back, start waiting for fresh data
            r_UartReadingStateMachine <= state_Idle;
            o_Uart_Tx_Active <= '0';
        when others =>
            r_UartReadingStateMachine <= state_Idle;
        end case;
    end if;
    end process process_UART_TX;

end architecture RTL;