-- rx_controller_tb.vhd

-- This file contains the testbench for rx_controller.vhd.
-- It tests if a reset, false start bit caused by noise, framing error and a valid frame are all handled correctly.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity rx_controller_tb is
end rx_controller_tb;

architecture behavioural of rx_controller_tb is
    
    -- Rx controller io signals
    signal i_rx_sync    : std_logic;
    signal o_data_byte  : std_logic_vector(7 downto 0);
    signal o_byte_valid : std_logic;
    signal i_tick16x    : std_logic;
    
    -- 16x baud tick output
    signal o_tick16x    : std_logic;
    
    signal clk          : std_logic := '0';
    signal rst          : std_logic;
    
begin

    baud16x_inst : entity work.baud_tick_16x
        port map(
            o_tick16x => o_tick16x,
            clk => clk,
            rst => rst
            );

    UUT : entity work.rx_controller
        port map(
            i_rx_sync    => i_rx_sync,
            o_data_byte  => o_data_byte,
            o_byte_valid => o_byte_valid,
            i_tick16x    => o_tick16x,
            clk          => clk,
            rst          => rst
            );
            
    clk <= not clk after 10 ns; -- 20ns clock generation
    
    stim_proc : process
        variable v_error_count : integer := 0; -- Counts how many tests failed
        variable v_clk_counter : integer := 0; -- Counts the number of clock cycles elapsed for checking if the o_data_valid flag ever went high
        
        -- Waits n number of baud ticks
        procedure wait_ticks(constant n : in integer) is
        begin
            for i in 1 to n loop
                wait until rising_edge(clk) and o_tick16x = '1';
            end loop;
        end procedure;
        
        -- Sends 1 bit to the receiver controller for 1 full baud period
        procedure send_bit(constant bit_val : in std_logic) is
        begin
            i_rx_sync <= bit_val;
            wait_ticks(16);
        end procedure;
        
        -- Sends an 8N1 UART frame to the receiver controller
        procedure send_frame(constant data_byte : in std_logic_vector(7 downto 0);
                            constant stop_bit   : in std_logic) is -- able to control the stop bit value to simulate framing error
        begin
            send_bit('0'); -- Start bit
            
            for i in 0 to 7 loop
                send_bit(data_byte(i));
            end loop;
            
            i_rx_sync <= stop_bit; -- not using send_bit procedure so it immediately exits the send_frame procedure
        end procedure;
        
    begin
        
        -- TEST 1 : test that reset works in the middle of receiving a frame
        
        i_rx_sync <= '1';
        rst       <= '1';
        wait for 60 ns;
        wait until rising_edge(clk);
        
        send_bit('0'); -- Start bit to begin receive process
        send_bit('1');
        
        -- Toggle reset and make input high(no start bit) so that if reset worked, o_data_valid will never go high 
        wait until rising_edge(clk);
        rst <= '0'; --active low
        wait for 60 ns;
        wait until rising_edge(clk);
        rst <='1';
        i_rx_sync <= '1';
        
        -- Make a loop that detects if o_byte_valid ever goes high
        -- 10 bits * 16 ticks/bit * 27 clock cycles(approx) = 4320 clocks/frame(approx), use 4500 to make sure o_byte_valid going high is detected
        for i in 1 to 4500 loop
        
            wait until rising_edge(clk);
            if o_byte_valid = '1' then
                
                v_error_count := v_error_count + 1;
                report("ERROR : TEST 1 FAILED. o_byte_valid went high even though reset went high in the middle of receiving a frame");
               
            end if;
        end loop;
        ----------------------------------------------------------------------------------------------------------------------------------------
        
        -- TEST 2 : test if a false start bit caused by noise stops the controller from receiving and outputting a byte
        
        -- Noise causing signal to be drawn low for three 16x ticks
        i_rx_sync <= '0';
        wait_ticks(3);
        i_rx_sync <= '1';
        
        -- Make a loop that detects if o_byte_valid ever goes high
        -- 10 bits * 16 ticks * 27 clock cycles(approx) = 4320 clocks/frame(approx), use 4500 to make sure o_byte_valid going high is detected
        for i in 1 to 4500 loop
        
            wait until rising_edge(clk);
            if o_byte_valid = '1' then
                
                v_error_count := v_error_count + 1;
                report("ERROR : TEST 2 FAILED. Receiver controller accepted noise as real start bit and o_data_valid went high");
               
            end if;
        end loop;
        ----------------------------------------------------------------------------------------------------------------------------------------
        
        -- TEST 3 : test if the receiver can detect a framing error and if so, output 0x3F (ASCII ?)
        
        send_frame(x"B5", '0'); -- Send data byte 0xB5 and no stop bit
        
        v_clk_counter := 0;
        
        -- 16 ticks * 27 clock cycles(approx) = 432 clock cycles/bit sent(approx). Use 500 incase of any discrepancy
        while o_byte_valid = '0' and v_clk_counter < 500 loop
            wait until rising_edge(clk);
            v_clk_counter := v_clk_counter + 1;
        end loop;
        
        if v_clk_counter = 500 then
        
            v_error_count := v_error_count + 1;
            report("ERROR : TEST 3 FAILED. o_data_valid did not go high despite the framing error.");
            
        elsif o_data_byte /= x"3F" then
            
            v_error_count := v_error_count + 1;
            report("ERROR : TEST 3 FAILED. Receiver controller did not output ASCII ? when a framing error was detected.");
            
        end if;
        ----------------------------------------------------------------------------------------------------------------------------------------
        
        -- TEST 4 : test a valid frame being received
        
        i_rx_sync <= '1';-- reset i_rx_sync
        wait_ticks(16);
        
        send_frame(x"B5", '1');
        
        v_clk_counter := 0;
        
        -- 16 ticks * 27 clock cycles(approx) = 432 clock cycles/bit sent(approx). Use 500 incase of any discrepancy
        while o_byte_valid = '0' and v_clk_counter < 500 loop
            wait until rising_edge(clk);
            v_clk_counter := v_clk_counter + 1;
        end loop;
        
        if v_clk_counter = 500 then
        
            v_error_count := v_error_count + 1;
            report("ERROR : TEST 4 FAILED. o_data_valid did not go high even though valid frame was received.");
            
        elsif o_data_byte /= x"B5" then
        
            v_error_count := v_error_count + 1;
            report("ERROR : TEST 4 FAILED. Receiver did not ouput expected 0xB5 when a valid frame was received.");
        
        end if;
        ----------------------------------------------------------------------------------------------------------------------------------------
        
        if v_error_count = 0 then
            report("SIMULATION PASSED");
        else
            assert false
                report("SIMULATION FAILED:" & integer'image(v_error_count) & " error(s).")
                severity failure;
        end if;
        
        wait;
    end process;
end behavioural;
    