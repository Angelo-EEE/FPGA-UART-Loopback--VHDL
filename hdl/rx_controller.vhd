-- rx_controller.vhd

-- This file contains the UART Receiver Controller. 
-- It uses an FSM and the 16x baud tick to detect and verify the start bit, sample the middle of the period of each incoming bit,
-- and check if there are any framing errors by checking for a stop bit.
-- If a framing error occured, the receiver controller will ouput the ASCII for ? so that framing errors can be seen by the users from the serial monitor

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rx_controller is
    port(
        i_rx_sync       : in std_logic;
        o_data_byte     : out std_logic_vector(7 downto 0);
        o_byte_valid    : out std_logic;
        
        i_tick16x       : in std_logic;
        clk             : in std_logic;
        rst             : in std_logic
        );
end rx_controller;

architecture rtl of rx_controller is

    signal r_sample_count : unsigned(3 downto 0) := "0000";
    signal r_bit_count    : unsigned(2 downto 0) := "000";
    
    signal r_data_byte     : std_logic_vector(7 downto 0) := x"00";
    signal r_byte_valid    : std_logic := '0';
    signal r_framing_error : std_logic := '0';
    
    type rx_state is (IDLE, CHECK, RECEIVE, STOP);
    signal state : rx_state := IDLE;
    
begin

    async_rx_proc : process(rst, clk)
    begin
        
        if rst = '0' then -- active low
        
            r_sample_count  <= "0000";
            r_bit_count     <= "000";
            r_data_byte     <= x"00";
            r_byte_valid    <= '0';
            state           <= IDLE;
            
        elsif rising_edge(clk) then
        
            r_byte_valid <= '0'; -- Allows for byte valid signal to be high for one clock cycle before it is driven low again
        
            if i_tick16x = '1' then
            
                case state is
                
                -- Detects potential start bit
                when IDLE =>
                        
                    if i_rx_sync = '0' then
                    
                        r_sample_count  <= "0000";
                        r_bit_count     <= "000";
                        state           <= CHECK;
                        
                    end if;
                
                -- Checks if signal drawn low was due to noise or is actually start bit
                when CHECK =>
                
                    r_sample_count <= r_sample_count + 1;
                    
                    if r_sample_count = "0111" then
                    
                        if i_rx_sync = '0' then
                            
                            r_data_byte    <= x"00";
                            r_sample_count <= "0000";
                            state          <= RECEIVE;
                        
                        else
                        
                            state <= IDLE;
                            r_sample_count <= "0000";
                            
                        end if;
                        
                    end if;
                
                -- store and sample the recieved data bits in the middle of each bit's signal so that transitions between 1 and 0 aren't sampled and so do not give false results
                when RECEIVE =>
                    
                    if r_sample_count = "1111" then
                    
                        r_data_byte    <= i_rx_sync & r_data_byte(7 downto 1);
                        r_sample_count <= "0000";
                    
                        if r_bit_count = "111" then
                        
                            r_bit_count <= "000";
                            state <= STOP;
                            
                        else 
                        
                            r_bit_count <= r_bit_count + 1;
                            
                        end if;
                        
                    else 
                    
                        r_sample_count <= r_sample_count + 1;
                        
                    end if;
                
                -- Check for stop bit. If no stop bit then framing error has occured and a ? is outputted
                when STOP =>

                    if r_sample_count = "1111" then

                        if i_rx_sync = '0' then

                            r_data_byte <= x"3F";
                            
                        end if;
                        
                        r_byte_valid <= '1';
                        state <= IDLE;
                        r_sample_count <= "0000";
                        
                    else 
                        
                        r_sample_count <= r_sample_count + 1;

                    end if;
                    
                end case;
                
            end if;
            
        end if;
            
    end process;
    
    o_data_byte     <= r_data_byte;
    o_byte_valid    <= r_byte_valid;
    
end rtl;