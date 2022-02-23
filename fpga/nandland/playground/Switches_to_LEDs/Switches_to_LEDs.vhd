library ieee;
use ieee.std_logic_1164.all;


entity Switches_to_LEDs is
    port (
        i_Clk : in std_logic;
        i_Switch_1  : in std_logic;
        i_Switch_2  : in std_logic;
        i_Switch_3  : in std_logic;
        i_Switch_4  : in std_logic;
        o_LED_1 : out std_logic;
        o_LED_2 : out std_logic;
        o_LED_3 : out std_logic;
        o_LED_4 : out std_logic
    );
end entity Switches_to_LEDs;

architecture RTL of Switches_to_LEDs is
    signal r_LED_1 : std_logic := '0';
    signal r_Switch_1 : std_logic := '0';
    signal w_Switch_1 : std_logic;
     
begin
    Debouncer_instance : entity work.Debounce_Switch
    port map (
        i_Clk  => i_Clk,
        i_Switch => i_Switch_1,
        o_Switch => w_Switch_1
    );

    p_register : process(i_Clk) is
    begin
        if rising_edge(i_Clk) then
            r_Switch_1 <= w_Switch_1;

             if w_Switch_1 = '0' and r_Switch_1 = '1' then --Falling Edge of switch
                r_LED_1 <= not r_LED_1;
            end if;
        end if ;
    end process p_register;

    o_LED_1 <= r_LED_1;
end architecture RTL;