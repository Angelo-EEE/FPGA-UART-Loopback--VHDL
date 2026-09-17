 -- FIFO.vhd

-- This file contains the FIFO used to store and read the data bytes coming into the UART loopback system.
-- The FIFO acts as a sort of buffer incase of timing mismatch or transmission delays so that the receiver and transmitter do not need to be perfectly synchronised.
-- This FIFO is 8 bits wide and 4 words deep.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity FIFO is
    port(
        i_wr_data   : in std_logic_vector(7 downto 0);
        i_wr_enable : in std_logic;
        i_rd_enable : in std_logic;
        
        o_rd_data      : out std_logic_vector(7 downto 0);
        o_full         : out std_logic;
        o_empty        : out std_logic;
        o_almost_full  : out std_logic;
        o_almost_empty : out std_logic;
        
        clk : in std_logic;
        rst : in std_logic
        );
end FIFO;

architecture rtl of FIFO is
    
    signal r_wr_pointer : unsigned(1 downto 0) := "00";-- Points to write location in FIFO
    signal r_rd_pointer : unsigned(1 downto 0) := "00";-- Points to read location in FIFO
    signal r_count      : integer range 0 to 4 := 0;-- Counts how many words in the FIFO are full
    
    type fifo_array is array(3 downto 0) of std_logic_vector(7 downto 0);-- FIFO, 8 bits in width, 4 words in depth
    signal r_fifo_data : fifo_array;
    
begin

    fifo_proc : process(clk, rst)
    begin
    
        if rst = '0' then --Resets all registers and clears FIFO
            
            r_fifo_data(0) <= x"00";
            r_fifo_data(1) <= x"00";
            r_fifo_data(2) <= x"00";
            r_fifo_data(3) <= x"00";
            
            r_wr_pointer <= "00";
            r_rd_pointer <= "00";
            r_count      <= 0;
            
        elsif rising_edge(clk) then
        
            -- If write enable and read enable and not empty, count stays same, write input data to write pointer location
            if i_wr_enable = '1' and i_rd_enable = '1' and r_count /= 0 then
            
                r_wr_pointer <= r_wr_pointer + 1;
                r_rd_pointer <= r_rd_pointer + 1;
                r_fifo_data(to_integer(r_wr_pointer)) <= i_wr_data;
                
            -- If write enable and not full, then count = count +1, write inpute data to write pointer location
            elsif i_wr_enable = '1' and r_count /= 4 then
            
                r_wr_pointer <= r_wr_pointer + 1;
                r_fifo_data(to_integer(r_wr_pointer)) <= i_wr_data;
                r_count <= r_count + 1;
                
            -- If read enable and not empty, then count = count -1
            elsif i_rd_enable = '1' and r_count /= 0 then
            
                r_rd_pointer <= r_rd_pointer + 1;
                r_count <= r_count - 1;
                
            end if;
            
        end if;
        
    end process;
        
    o_empty        <= '1' when (r_count = 0) else '0';
    o_almost_empty <= '1' when (r_count = 1) else '0';
    o_almost_full  <= '1' when (r_count = 3) else '0';
    o_full         <= '1' when (r_count = 4) else '0'; 
    
    -- Output the byte at location where read pointer is. This byte will only be read when read enable signal outputted from transmitter is high
    o_rd_data <= r_fifo_data(to_integer(r_rd_pointer));
    
end rtl;