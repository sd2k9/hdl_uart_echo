--     Testbench.vhdl - UART Echo for Xilinx Coolrunner II Starter Board - Testbench
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



-- *** Includes
library ieee;
use ieee.std_logic_1164.all;

entity Testbench is
  generic
    (
      -- The Pin Clock Rate
      CLOCK_PERIOD     : time    := 125 ns  -- 8 MHz
      -- Baud Rate Setting in bps
      UART_BAUD_RATE : natural := 4800    -- 4800bps
      );

end entity Testbench;

architecture beh of Testbench is

  ----------------------------------------------------------------------------
  -- Signals
  ----------------------------------------------------------------------------
  -- Control
  signal clock:    std_ulogic := '0';   -- clock
  signal rst_n:    std_ulogic;          -- low-active reset
  -- DUT
  signal uart_rx    : std_ulogic;
  signal uart_tx    : std_ulogic;

  -- Sync signals
  signal start_the_action : boolean := false;  -- true: Sending/Receiving in TB enabled
  ----------------------------------------------------------------------------
  -- Stimuli to apply
  ----------------------------------------------------------------------------
  -- A number of 8 bit values
  type stimuli_type is array (natural range <>) of std_ulogic_vector(7 downto 0);
  -- Just fill with some sample values
  constant STIMULI_DATA : stimuli_type := (x"AA", x"1F", x"D4");

  ----------------------------------------------------------------------------
  -- Constants
  ----------------------------------------------------------------------------
  -- UART Bit Timing, by Baud Rate setting
  constant UART_BIT_TIME : time := (1 s/UART_BAUD_RATE);
  -- Break between data bytes send (can be also zero for successive bursts)
  constant WAIT_BEFORE_SEND : time := 10 us;

begin  -- architecture beh


  ----------------------------------------------------------------------------
  -- DUT (Direct) Instance
  ----------------------------------------------------------------------------
  dut: entity work.uart_echo_top
    generic map (
      CLOCK_PERIOD_BEFORE_CLKDIV => CLOCK_PERIOD,
      UART_BAUD_RATE             => UART_BAUD_RATE)
    port map (
      clk        => clock,
      reset_n    => rst_n,
      uart_rx    => uart_rx,            -- in
      uart_tx    => uart_tx,            -- out
      disp_ena_n => open,
      disp_seg_n => open);


  ----------------------------------------------------------------------------
  -- Start testbench behaviour
  ----------------------------------------------------------------------------
  kickstarter: process is
  begin  -- process kickstarter
    wait for 1 ns;                      -- Skip possible initial value
    wait until rising_edge(rst_n);
    wait for 1 ms;                      -- some more time to allow the dut to settle
    start_the_action <= true;           -- Now we're running
    wait;
  end process kickstarter;

  ----------------------------------------------------------------------------
  -- Apply stimulus
  ----------------------------------------------------------------------------
  report "Bit time setting = " & UART_BIT_TIME severity note;  -- Debug
  tb_send : process is
    -- Variable definitions
    variable databyte : STIMULI_DATA'element;  -- Our sending worker
  begin  -- process tb_send
    -- First wait for reset to go down
    uart_rx <= '1';                     -- Initial value
    wait until start_the_action = true;  -- Skip dut initialisation time
    for stimu_idx in STIMULI_DATA'range loop  -- loop over all stimuli
      databyte := STIMULI_DATA(stimu_idx);
      wait for WAIT_BEFORE_SEND;        -- some initial waiting time
      report "RX: Start sending data byte: " & databyte & " (" & to_hstring(databyte) & ")" severity note;
      -- Send Start bit
      uart_rx <= '0';
      wait UART_BIT_TIME;
      -- Send all data bits
      for schl in 0 to 7 loop
        uart_rx <= databyte(schl);
        wait UART_BIT_TIME;
      end loop;  -- schl
      -- Send Stop bit
      uart_rx <= '1';
      wait UART_BIT_TIME;
      -- Done!
      report "RX: Done sending data byte: " & databyte & " (" & to_hstring(databyte) & ")" severity note;
    end loop;  -- stimu
  end process tb_send;


  ----------------------------------------------------------------------------
  -- Regenerate data send from the device
  ----------------------------------------------------------------------------
  tb_receive: process is
    -- Variable definitions
    variable databyte : STIMULI_DATA'element;  -- The received data byte
  begin  -- process tb_receive
    wait until start_the_action = true;  -- Skip dut initialisation time
    loop                                -- Receiver Loop
       assert uart_tx = '1' report "uart_tx not idle before receiving! Something's wrong and will most probably stay this way" severity error;
       wait until falling_edge(uart_tx);  -- This is our start bit
       report "TX: Start receiving data byte" severity note;
       wait for UART_BIT_TIME/2;          -- we will sample in the middle of the bit
       assert uart_tx = '0' report "Start bit is not 0! Something's wrong and will most probably stay this way" severity error;
       wait for UART_BIT_TIME;
       -- now get our 8 data bits
       for schl in 0 to 7 loop
         databyte(schl) := uart_rx;
         wait for UART_BIT_TIME;
       end loop;  -- schl
       assert uart_tx = '1' report "Stop bit is not 1! Something's wrong and will most probably stay this way" severity error;
       report "TX: Done receiving data byte: " & databyte & " (" & to_hstring(databyte) & ")" severity note;
    end loop;
  end process tb_receive;


  ----------------------------------------------------------------------------
  -- Check receive line for bit length and spike-freeness
  ----------------------------------------------------------------------------
  recv_spike_check: process is
    variable pulse_start : time = 0 ps;        -- Start of any pulse
    constant SPIKE_BORDER : time := 0.9 * UART_BIT_TIME;  -- Smaller pulses are spikes
  begin  -- process recv_spike_check
    wait until start_the_action = true;  -- Skip dut initialisation time
    -- Any state change faster than 90% of expected bit time is a real error
    -- and will be reported as potential spike
    loop
      wait on uart_tx;                  -- wait for next change
      assert now - pulse_start > SPIKE_BORDER report "Spike in UART TX line detected! Check your model or bit timing" severity error;
      pulse_start = now;
    end loop;
  end process recv_spike_check;

  recv_bitrate_check: process is
    variable pulse_start : time;                 -- Start of any pulse
    variable min_bit_time : time := 999 s;       -- Minimum bit time found
  begin
    wait until start_the_action = true;  -- Skip dut initialisation time
    wait on uart_tx;                  -- wait for next change, set initial value
    pulse_start := now;
    -- Veery simple approach; Check continuously and report always smallest value
    loop
      wait on uart_tx;                  -- wait for next change
      if now - pulse_start < min_bit_time then
        min_bit_time := now - pulse_start;  -- smaller value found
        -- Report it
        report "Minimum bit time found until now: " & min_bit_time & " = " & (1 s / min_bit_time) & "bps (will report on next smaller value"
          severity note;
        report "Error to expected bit rate: " & (100 * (UART_BIT_TIME - min_bit_time) / UART_BIT_TIME) & "%" severity note;
      end if;
    end loop;  -- schl
  end process recv_bitrate_check;

  ----------------------------------------------------------------------------
  -- Clock and Reset
  ----------------------------------------------------------------------------
  -- Clock Process
  process is
  begin
    wait for CLOCK_PERIOD/2;
    clock <= not clock;
  end process;

  -- RST Process
  process is
  begin
    wait for 150 ns;
    rst_n <= '0';                       -- Do reset
    wait for 1 ms;
    rst_n <= '1';                       -- Release reset
    wait;                               -- Done forever
  end process;


end architecture beh;
