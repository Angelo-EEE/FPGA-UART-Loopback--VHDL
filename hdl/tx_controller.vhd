-- tx_controller.vhd

-- This file contains the UART Transmitter Controller.
-- It takes the data byte at the read pointer location in the FIFO if the FIFO's empty flag is low.
-- The data byte is then transmitted along with the start and stop bits.
-- This is done at 115200 baud by counting the 16x baud tick created in the baud_tick_16x.vhd file 16 times before shifting the output to the next bit.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity tx_controller is
    port(
        i_rd_data    : in std_logic_vector(7 downto 0);
        i_tick16x    : in std_logic;
        i_fifo_empty : in std_logic;
        
        o_data_bit   : out std_logic;
        o_rd_enable  : out std_logic;
        
        clk : in std_logic;
        rst : in std_logic
        );
end tx_controller;

architecture rtl of tx_controller is

    signal r_shift_reg : std_logic_vector(9 downto 0) := (others => '1');
    signal r_rd_enable : std_logic := '0';
    
    signal r_tick16x_count : integer range 0 to 15 := 0;
    signal r_bit_count     : integer range 0 to 9  := 0;
    
    type tx_state is (IDLE, TRANSMIT);
    signal state : tx_state := IDLE;
    
begin

    tx_proc : process(rst, clk)
    begin
    
        if rst = '0' then -- Resets all registers and state to IDLE
    
            r_shift_reg     <= (others => '1'); -- No start bit
            r_rd_enable     <= '0';
            r_tick16x_count <= 0;
            r_bit_count     <= 0;
            
            state <= IDLE;
            
        elsif rising_edge(clk) then
            
            r_rd_enable <= '0'; -- Only allows read enable to be high for one clock
            
            case state is
            
            -- Reset registers and if the FIFO is not empty then reads the data byte from the FIFO and goes to TRANSMIT state
            when IDLE =>
            
                r_shift_reg     <= (others => '1');
                r_tick16x_count <= 0;
                r_bit_count     <= 0;
            
                if i_fifo_empty = '0' then
                    
                    r_rd_enable <= '1';
                    r_shift_reg <= '1' & i_rd_data & '0'; -- Includes start and stop bits
                    state <= TRANSMIT;
                    
                end if;
            
            -- Counts 16 ticks and then shifts the shift register until all bits transmittedand then goes to IDLE state
            when TRANSMIT =>
                
                if i_tick16x = '1' then
                
                    if r_tick16x_count = 15 then
                        
                        r_tick16x_count <= 0;
                        
                        if r_bit_count = 9 then
                        
                            r_bit_count <= 0;
                            state <= IDLE;
                        
                        else 
                        
                            r_shift_reg <= '1' & r_shift_reg(9 downto 1);
                            r_bit_count <= r_bit_count + 1;
                        
                        end if;
                        
                    else
                    
                        r_tick16x_count <= r_tick16x_count + 1;
                        
                    end if;
                    
                end if;
                
            end case;
            
        end if;
            
        end process;
        
        o_data_bit  <= r_shift_reg(0); -- Always outputs LSB of shift register
        o_rd_enable <= r_rd_enable;

end rtl;
