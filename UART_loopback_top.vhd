----------------------------------------------------------------------
-- Created by SmartDesign Tue Sep 15 19:11:11 2026
-- Version: 2026.1 2026.1.0.17
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Libraries
----------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library polarfire;
use polarfire.all;
----------------------------------------------------------------------
-- UART_loopback_top entity declaration
----------------------------------------------------------------------
entity UART_loopback_top is
    -- Port list
    port(
        -- Inputs
        clk            : in  std_logic;
        i_serial_rx    : in  std_logic;
        rst            : in  std_logic;
        -- Outputs
        o_almost_empty : out std_logic;
        o_almost_full  : out std_logic;
        o_data_bit     : out std_logic;
        o_empty        : out std_logic;
        o_full         : out std_logic
        );
end UART_loopback_top;
----------------------------------------------------------------------
-- UART_loopback_top architecture body
----------------------------------------------------------------------
architecture RTL of UART_loopback_top is
----------------------------------------------------------------------
-- Component declarations
----------------------------------------------------------------------
-- baud_tick_16x
component baud_tick_16x
    -- Port list
    port(
        -- Inputs
        clk       : in  std_logic;
        rst       : in  std_logic;
        -- Outputs
        o_tick16x : out std_logic
        );
end component;
-- FIFO
component FIFO
    -- Port list
    port(
        -- Inputs
        clk            : in  std_logic;
        i_rd_enable    : in  std_logic;
        i_wr_data      : in  std_logic_vector(7 downto 0);
        i_wr_enable    : in  std_logic;
        rst            : in  std_logic;
        -- Outputs
        o_almost_empty : out std_logic;
        o_almost_full  : out std_logic;
        o_empty        : out std_logic;
        o_full         : out std_logic;
        o_rd_data      : out std_logic_vector(7 downto 0)
        );
end component;
-- rx_controller
component rx_controller
    -- Port list
    port(
        -- Inputs
        clk          : in  std_logic;
        i_rx_sync    : in  std_logic;
        i_tick16x    : in  std_logic;
        rst          : in  std_logic;
        -- Outputs
        o_byte_valid : out std_logic;
        o_data_byte  : out std_logic_vector(7 downto 0)
        );
end component;
-- serial_rx_sync
component serial_rx_sync
    -- Port list
    port(
        -- Inputs
        clk         : in  std_logic;
        i_serial_rx : in  std_logic;
        rst         : in  std_logic;
        -- Outputs
        o_rx_sync   : out std_logic
        );
end component;
-- tx_controller
component tx_controller
    -- Port list
    port(
        -- Inputs
        clk          : in  std_logic;
        i_fifo_empty : in  std_logic;
        i_rd_data    : in  std_logic_vector(7 downto 0);
        i_tick16x    : in  std_logic;
        rst          : in  std_logic;
        -- Outputs
        o_data_bit   : out std_logic;
        o_rd_enable  : out std_logic
        );
end component;
----------------------------------------------------------------------
-- Signal declarations
----------------------------------------------------------------------
signal baud_tick_16x_0_o_tick16x    : std_logic;
signal FIFO_0_o_rd_data             : std_logic_vector(7 downto 0);
signal o_almost_empty_net_0         : std_logic;
signal o_almost_full_net_0          : std_logic;
signal o_data_bit_net_0             : std_logic;
signal o_empty_net_0                : std_logic;
signal o_full_net_0                 : std_logic;
signal rx_controller_0_o_byte_valid : std_logic;
signal rx_controller_0_o_data_byte  : std_logic_vector(7 downto 0);
signal serial_rx_sync_0_o_rx_sync   : std_logic;
signal tx_controller_0_o_rd_enable  : std_logic;
signal o_data_bit_net_1             : std_logic;
signal o_almost_full_net_1          : std_logic;
signal o_full_net_1                 : std_logic;
signal o_empty_net_1                : std_logic;
signal o_almost_empty_net_1         : std_logic;

begin
----------------------------------------------------------------------
-- Top level output port assignments
----------------------------------------------------------------------
 o_data_bit_net_1     <= o_data_bit_net_0;
 o_data_bit           <= o_data_bit_net_1;
 o_almost_full_net_1  <= o_almost_full_net_0;
 o_almost_full        <= o_almost_full_net_1;
 o_full_net_1         <= o_full_net_0;
 o_full               <= o_full_net_1;
 o_empty_net_1        <= o_empty_net_0;
 o_empty              <= o_empty_net_1;
 o_almost_empty_net_1 <= o_almost_empty_net_0;
 o_almost_empty       <= o_almost_empty_net_1;
----------------------------------------------------------------------
-- Component instances
----------------------------------------------------------------------
-- baud_tick_16x_0
baud_tick_16x_0 : baud_tick_16x
    port map( 
        -- Inputs
        clk       => clk,
        rst       => rst,
        -- Outputs
        o_tick16x => baud_tick_16x_0_o_tick16x 
        );
-- FIFO_0
FIFO_0 : FIFO
    port map( 
        -- Inputs
        i_wr_enable    => rx_controller_0_o_byte_valid,
        i_rd_enable    => tx_controller_0_o_rd_enable,
        clk            => clk,
        rst            => rst,
        i_wr_data      => rx_controller_0_o_data_byte,
        -- Outputs
        o_full         => o_full_net_0,
        o_empty        => o_empty_net_0,
        o_almost_full  => o_almost_full_net_0,
        o_almost_empty => o_almost_empty_net_0,
        o_rd_data      => FIFO_0_o_rd_data 
        );
-- rx_controller_0
rx_controller_0 : rx_controller
    port map( 
        -- Inputs
        i_rx_sync    => serial_rx_sync_0_o_rx_sync,
        i_tick16x    => baud_tick_16x_0_o_tick16x,
        clk          => clk,
        rst          => rst,
        -- Outputs
        o_byte_valid => rx_controller_0_o_byte_valid,
        o_data_byte  => rx_controller_0_o_data_byte 
        );
-- serial_rx_sync_0
serial_rx_sync_0 : serial_rx_sync
    port map( 
        -- Inputs
        i_serial_rx => i_serial_rx,
        clk         => clk,
        rst         => rst,
        -- Outputs
        o_rx_sync   => serial_rx_sync_0_o_rx_sync 
        );
-- tx_controller_0
tx_controller_0 : tx_controller
    port map( 
        -- Inputs
        i_rd_data    => FIFO_0_o_rd_data,
        i_tick16x    => baud_tick_16x_0_o_tick16x,
        i_fifo_empty => o_empty_net_0,
        clk          => clk,
        rst          => rst,
        -- Outputs
        o_data_bit   => o_data_bit_net_0,
        o_rd_enable  => tx_controller_0_o_rd_enable 
        );

end RTL;
