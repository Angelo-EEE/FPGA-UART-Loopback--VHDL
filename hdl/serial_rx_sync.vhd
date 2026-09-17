-- serial_rx_sync.vhd

-- This file contains the UART receiver synchroniser. It synchronises the incoming signal to the receiver's clock domain and reduces the risk of metastability
-- by passing the incoming signal through two D flip-flops.

library IEEE;
use IEEE.std_logic_1164.all;

entity serial_rx_sync is
    port(
        i_serial_rx : in std_logic;
        o_rx_sync   : out std_logic;
        
        clk         : in std_logic;
        rst         : in std_logic
        );
end serial_rx_sync;

architecture rtl of serial_rx_sync is
    
    signal r_ff1 : std_logic := '1'; -- no start bit
    signal r_ff2 : std_logic := '1';
    
begin

    sync_proc : process(rst, clk)
    begin
    
        if rst = '0' then -- active low
        
            r_ff1 <= '1'; -- no start bit
            r_ff2 <= '1';
            
        elsif rising_edge(clk) then
        
            r_ff1 <= i_serial_rx;
            r_ff2 <= r_ff1;
            
        end if;
        
    end process;
    
    o_rx_sync <= r_ff2;
    
end rtl;