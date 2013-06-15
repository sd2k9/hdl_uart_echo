--     uart_echo_top.vhdl - UART Echo for Xilinx Coolrunner II Starter Board
--     Copyright (C) 2013, Robert Lange <robert.lange@s1999.tu-chemnitz.de>
--
--     This program is free software: you can redistribute it and/or modify
--     it under the terms of the GNU General Public License as published by
--     the Free Software Foundation, either version 3 of the License, or
--     (at your option) any later version.
--
--     This program is distributed in the hope that it will be useful,
--     but WITHOUT ANY WARRANTY; without even the implied warranty of
--     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--     GNU General Public License for more details.
--
--     You should have received a copy of the GNU General Public License
--     along with this program.  If not, see <http://www.gnu.org/licenses/>.

-- *** Toplevel Module
-- Based on LGPL code from Peter A Bennett, https://github.com/pabennett/uart
-- The toplevel implements a 4800bps UART echo for the
-- Xilinx Coolrunner II Starter Board
-- Connect the TODO (or compatible) to the CONNECTOR TODO


-- Libraries to use
library ieee;
use ieee.std_logic_1164.all;
-- Xilinx Primitives
library UNISIM;

-- *** Entity of the design
entity uart_echo_top is
  generic
    (
      -- Clock frequency AFTER Clock Divider in Hz -- "time" is not synthesizable
      CLOCK_FREQUENCY_AFTER_CLKDIV : positive := 1e6 ;  -- 1 MHz
      -- Baud Rate Setting in bps
      UART_BAUD_RATE               : natural := 4800 ;  -- 4800bps
      -- When true generate code to debounce and synchronize the external reset
      -- This setting blocks GSR inferrence for Xilinx CoolRunner CPLD device
      -- DEBOUNCE_SYNCHRONIZE_RESET   : boolean := true
      DEBOUNCE_SYNCHRONIZE_RESET   : boolean := false
      );

  port
    (
      -- Control Signals
      clk        : in  std_logic;                 -- Clock Signals
      reset_n    : in  std_logic;                 -- low active reset - use signal "reset" in design
      -- UART Signals
      uart_rx    : in  std_logic;          -- Receive Signal - use uart_rx_int in design
      uart_tx    : out std_logic;          -- Transmit Signal
      -- Other ports of Reference Board - not used
      -- btn1       : in std_logic;  -- 2nd Push Button (low active)
      -- sw0, sw1   : in std_logic;  -- slide buttons
      -- 7 Segment Display - all low active; see Reference Manual
      led_n      : out std_logic_vector(3 downto 0);  -- 4 User LEDs (low active)
      disp_ena_n : out std_logic_vector(1 to 4);  -- 4 Digit Enabler
      disp_seg_n : out std_logic_vector(1 to 8)   -- 7.1 Segments
      );

end entity uart_echo_top;

architecture rtl of uart_echo_top is

    ----------------------------------------------------------------------------
    -- Constants
    ----------------------------------------------------------------------------

    ----------------------------------------------------------------------------
    -- Component declarations
    ----------------------------------------------------------------------------
    component UART is
        generic (
                BAUD_RATE           : positive;
                CLOCK_FREQUENCY     : positive
            );
        port (  -- General
                CLOCK               :   in      std_logic;
                RESET               :   in      std_logic;
                DATA_STREAM_IN      :   in      std_logic_vector(7 downto 0);
                DATA_STREAM_IN_STB  :   in      std_logic;
                DATA_STREAM_IN_ACK  :   out     std_logic;
                DATA_STREAM_OUT     :   out     std_logic_vector(7 downto 0);
                DATA_STREAM_OUT_STB :   out     std_logic;
                DATA_STREAM_OUT_ACK :   in      std_logic;
                TX                  :   out     std_logic;
                RX                  :   in      std_logic
             );
    end component UART;

    ----------------------------------------------------------------------------
    -- signals
    ----------------------------------------------------------------------------
    -- Control signals - use them
    signal clk_div_out : std_ulogic;     -- Clock after Clock Divider
    signal reset : std_ulogic;           -- High-Active Reset - use this signal
                                         -- as async reset for GSR inferrence
    -- Internal uart_rx signal, after debouncer and sync stage
    signal uart_rx_int   : std_ulogic;
    -- UART Signals for loopback test, initialize inputs
    signal uart_data_in             : std_logic_vector(7 downto 0) := (others => '0');
    signal uart_data_out            : std_logic_vector(7 downto 0);
    signal uart_data_in_stb         : std_ulogic := '0';
    signal uart_data_in_ack         : std_ulogic;
    signal uart_data_out_stb        : std_ulogic;
    signal uart_data_out_ack        : std_ulogic := '0';

begin  -- architecture rtl

  -----------------------------------------------------------------------------
  --   Provide divided CLK (Xilinx CPLD Macro)
  -----------------------------------------------------------------------------
  -- CLK_DIV8: Simple clock Divide by 8
  --             CoolRunner-II
  -- Xilinx HDL Language Template, version 14.5
  clk_div8_inst : component UNISIM.vcomponents.CLK_DIV8
    port map (
      CLKDV => clk_div_out,    -- Divided clock output
      CLKIN => clk             -- Clock input
   );

  ----------------------------------------------------------------------------
  -- Double-Deglitch and register input UART_RX
  ----------------------------------------------------------------------------
  -- Deglitching of uart_rx not really necessary, because the uart receiver
  -- itself does another synchronizing step
  DEGLITCH_UART_RX : block is
    signal uart_rx_sync1 : std_ulogic;
    signal uart_rx_reg   : std_ulogic;
  begin  -- DEGLITCH_UART_RX
    process (clk_div_out)
    begin
      if rising_edge(clk_div_out) then
        uart_rx_sync1 <= uart_rx;
        uart_rx_reg   <= uart_rx_sync1;
      end if;
    end process;
  -- Assign-back the signal to use
   uart_rx_int <= uart_rx_reg;
  end block DEGLITCH_UART_RX;

  ----------------------------------------------------------------------------
  -- DEBOUNCE_SYNCHRONIZE_RESET == true:
  --   Double-Deglitch, register and invert input RESET_N
  -- DEBOUNCE_SYNCHRONIZE_RESET == false:
  --   Just invert input RESET_N
  ----------------------------------------------------------------------------
  GENERATE_RESET_DEGLICH : if DEBOUNCE_SYNCHRONIZE_RESET = true generate
    DEGLITCH_RESET_N : block is
      signal reset_n_sync1 : std_ulogic;
      signal reset_n_reg   : std_ulogic;
    begin  -- DEGLITCH_RESET_N
      process (clk_div_out)
      begin
        if rising_edge(clk_div_out) then
          reset_n_sync1 <= reset_n;
          reset_n_reg   <= reset_n_sync1;
        end if;
      end process;
      -- Create High-active reset after register
      reset <= not reset_n_reg;
    end block DEGLITCH_RESET_N;
  end generate   GENERATE_RESET_DEGLICH;
  GENERATE_ASYC_RESET: if DEBOUNCE_SYNCHRONIZE_RESET = false generate
    -- Just invert reset
    reset <= not reset_n;
  end generate GENERATE_ASYC_RESET;

  ----------------------------------------------------------------------------
  -- UART instance
  ----------------------------------------------------------------------------
  UART_1 : UART
    generic map (
      -- Just forward the toplevel settings
      BAUD_RATE       => UART_BAUD_RATE,
      CLOCK_FREQUENCY => CLOCK_FREQUENCY_AFTER_CLKDIV)
    port map (
      CLOCK               => clk_div_out,
      RESET               => reset,
      DATA_STREAM_IN      => uart_data_in,
      DATA_STREAM_IN_STB  => uart_data_in_stb,
      DATA_STREAM_IN_ACK  => uart_data_in_ack,
      DATA_STREAM_OUT     => uart_data_out,
      DATA_STREAM_OUT_STB => uart_data_out_stb,
      DATA_STREAM_OUT_ACK => uart_data_out_ack,
      TX                  => uart_tx,
      RX                  => uart_rx_int);

    ----------------------------------------------------------------------------
    -- Simple loopback, retransmit any received data
    ----------------------------------------------------------------------------
    UART_LOOPBACK : process (clk_div_out, reset)
    begin
            if reset = '1' then
                uart_data_in_stb        <= '0';
                uart_data_out_ack       <= '0';
                uart_data_in            <= (others => '0');
            elsif rising_edge(clk_div_out) then
                -- Acknowledge data receive strobes and set up a transmission
                -- request
                uart_data_out_ack       <= '0';
                if uart_data_out_stb = '1' then
                    uart_data_out_ack   <= '1';
                    uart_data_in_stb    <= '1';
                    uart_data_in        <= uart_data_out;
                end if;

                -- Clear transmission request strobe upon acknowledge.
                if uart_data_in_ack = '1' then
                    uart_data_in_stb    <= '0';
                end if;
        end if;
    end process;


  ----------------------------------------------------------------------------
  -- Simple signals
  ----------------------------------------------------------------------------
  -- Just disable 7-segment display and LEDs
  disp_ena_n <= (others => '1');
  disp_seg_n <= (others => '1');
  led_n <=  (others => '1');

  ----------------------------------------------------------------------------
  -- Debug Report statements - Do not synthesize
  ----------------------------------------------------------------------------
  -- pragma translate_off
  debug_print: process
  begin
		report "Clock frequency after Clk Divider = " & real'image(real(CLOCK_FREQUENCY_AFTER_CLKDIV)/1.0e6) & " MHz" severity note;  -- Debug
	wait;
  end process debug_print;
   -- pragma translate_on
end architecture rtl;

