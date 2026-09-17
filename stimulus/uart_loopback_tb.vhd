-- uart_loopback_tb.vhd

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity uart_loopback_tb is
end uart_loopback_tb;

architecture behavioural of uart_loopback_tb is
    
    -- uart_loopback_top io
    signal i_serial_rx    : std_logic;
    signal o_almost_empty : std_logic;
    signal o_almost_full  : std_logic;
    signal o_empty        : std_logic;
    signal o_full         : std_logic;
    signal o_data_bit     : std_logic;
    
    signal clk : std_logic := '0';
    signal rst : std_logic;
    
    -- Baud rate timing (1s / 115200 baud = 8.68us per bit)
    constant c_bit_period : time := 1 sec / 115200;
    
    -- Signals to monitor and verify output bits
    signal captured_tx_byte : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_done          : std_logic := '0';
    
begin

    UUT : entity work.UART_loopback_top
        port map(
            i_serial_rx    => i_serial_rx,
            o_almost_empty => o_almost_empty,
            o_almost_full  => o_almost_full,
            o_empty        => o_empty,
            o_full         => o_full,
            o_data_bit     => o_data_bit,
            
            clk => clk,
            rst => rst
        );
        
    clk <= not clk after 10 ns; -- 20 ns clock
    
    -- Samples the o_data_bit to store the data bits as a byte to compare to the expected byte value
    monitor_proc : process
        variable v_rx_byte : std_logic_vector(7 downto 0);
    begin
        -- Wait for start bit on o_data_bit
        wait until falling_edge(o_data_bit);
        
        -- Wait 1.5 bit periods to sample at the midpoint of the bits
        wait for c_bit_period * 1.5;
        
        -- Sample the data bits
        for i in 0 to 7 loop
            v_rx_byte(i) := o_data_bit;
            if i < 7 then
                wait for c_bit_period;
            end if;
        end loop;
        
        --Sample stop bit
        wait for c_bit_period;
        assert o_data_bit = '1'
            report "ERROR : TX MONITOR. Missing stop bit on o_data_bit!"
            severity error;
        
        --Export sampled byte from o_data_bit
        captured_tx_byte <= v_rx_byte;
        tx_done          <= not tx_done;
    end process;
    
    stim_proc : process
        variable v_error_count : integer := 0;
        
        -- Sends 1 bit to the uart loopback system for 1 full baud period
        procedure send_bit(constant bit_val : in std_logic) is
        begin
            i_serial_rx <= bit_val;
            wait for c_bit_period;
        end procedure;
        
        -- Sends a uart 8N1 frame to the uart loopback system
        procedure send_frame(constant data_byte : in std_logic_vector(7 downto 0);
                            constant stop_bit   : in std_logic) is -- able to control the stop bit value to simulate framing error
        begin
            send_bit('0');
            
            for i in 0 to 7 loop
                send_bit(data_byte(i));
            end loop;
            
            send_bit(stop_bit);
        end procedure;
        
        -- Verifies captured output frame against expected value
        procedure verify_tx_output(constant expected_byte : in std_logic_vector(7 downto 0)) is
        begin
        
            wait on tx_done for c_bit_period * 15;
            
            if captured_tx_byte /= expected_byte then
                report "ERROR : OUTPUT DATA MISMATCH. Transmitted 0x" & to_hstring(captured_tx_byte) & 
                       " but expected 0x" & to_hstring(expected_byte)
                    severity error;
                v_error_count := v_error_count + 1;
            end if;
        end procedure;
        
    begin
            
        -- Test 1: check the FIFO empty, almost empty, almost full and full flags upon reset
        
        rst <= '0';
        i_serial_rx <= '1';
        wait for 60 ns;
        
        if not (o_empty = '1' and o_almost_empty = '0' and o_almost_full = '0' and o_full = '0') then
            report "ERROR : TEST 1 FAILED. FIFO flags incorrect upon reset."
                severity error;
            v_error_count := v_error_count + 1;
        end if;
        
        rst <= '1';
        wait for 60 ns;
        -----------------------------------------------------------------------------------------------------
        
        -- Test 2: test if after the UART loopback of 1 UART 8N1 frame, the o_empty flag goes high
        
        send_frame(x"55", '1');
        verify_tx_output(x"55");
        
        wait for c_bit_period * 2;
        if o_empty = '0' then
            report "ERROR : TEST 2 FAILED. FIFO did not return empty flag as high after loopback of 1 UART 8N1 frame."
                severity error;
            v_error_count := v_error_count + 1;
        end if;
        -----------------------------------------------------------------------------------------------------
        
        -- Test 3: test if a framing error occurs, whether the uart loopback returns an ASCII ?
        
        send_frame(x"A5", '0');
        verify_tx_output(x"3F"); -- ASCII ?
        -----------------------------------------------------------------------------------------------------
        
        -- Test 4: test if the uart loopback system can handle 8 frames being received back to back including a frame with a framing error
        
        send_frame(x"34", '1');
        verify_tx_output(x"34");
        
        send_frame(x"B7", '1');
        verify_tx_output(x"B7");
        
        send_frame(x"55", '1');
        verify_tx_output(x"55");
        
        send_frame(x"AA", '1');
        verify_tx_output(x"AA");
        
        send_frame(x"A5", '1');
        verify_tx_output(x"A5");
        
        send_frame(x"A5", '0');
        verify_tx_output(x"3F");
        
        send_frame(x"00", '1');
        verify_tx_output(x"00");
        
        send_frame(x"FF", '1');
        verify_tx_output(x"FF");

        wait for c_bit_period * 5;
        if o_empty = '0' then
            report "ERROR : TEST 3 FAILED. FIFO not empty after burst completion."
                severity error;
            v_error_count := v_error_count + 1;
        end if;

        -- ---------------------------------------------------------------------
        -- Simulation Summary Reporting
        -- ---------------------------------------------------------------------
        if v_error_count = 0 then
            report("SIMULATION PASSED");
        else
            assert false
                report("SIMULATION FAILED: " & integer'image(v_error_count) & " error(s).")
                severity failure;
        end if;

        wait;
    end process;

end behavioural;
    