--     TestBench_rtl_conf.vhdl - Configuration for RTL Testbench
--     of the UART Echo for Xilinx Coolrunner II Starter Board
--     No configuration for POST is required
--     Attention: For synthesis the generics are defined in the Synthesis options
--     Left Bar/Implement Design/Synthesize/Right Click Process Properties
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


-- Use configure for UART block from synthesis settings
configuration TestBench_rtl of TestBench is
  for beh                               -- architecture
    for dut : uart_echo_top
     use entity work.uart_echo_top(rtl)
     generic map (
      -- Clock frequency AFTER Clock Divider in Hz -- "time" is not synthesizable
      -- Constant in testbench
      CLOCK_FREQUENCY_AFTER_CLKDIV => CLOCK_FREQUENCY_AFTER_CLKDIV , -- 1 MHz
      -- Baud Rate Setting in bps
      UART_BAUD_RATE               => UART_BAUD_RATE ,  -- Take from Testbench
      -- When true generate code to debounce and synchronize the external reset
      -- This setting blocks GSR inferrence for Xilinx CoolRunner CPLD device
      -- DEBOUNCE_SYNCHRONIZE_RESET   => true
      DEBOUNCE_SYNCHRONIZE_RESET   => false
     );
    end for;
  end for;
end TestBench_rtl;
