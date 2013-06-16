UART Character Echo
====================

Function
--------
Echo incoming UART characters back to the sender.

This repository includes the Toplevel, test bench and the Xilinx ISE project.
The UART module is references as subproject below src/ext-uart/
    Source: https://github.com/sd2k9/uart

UART Communication settings:  4800bps, 8 Data, 1 Stop, No parity

Requirements
------------
- Device: Xilinx Coolrunner II
- Board: Coolrunner II Starter Board
- Extension Board: TODO
- Software: Xilinx ISE 14.5
- Terminal program: Under linux you can use minicom or cutecom

How to program the device
-------------------------
Just run the supplied script: ./uart_echo_ise/program_it.sh

License
-------
- GNU General Public License Version 3
- http://www.gnu.org/licenses/gpl.html

Homepage
--------
TODO - CORRECT ME
https://sethdepot.org/site/HdlLsiSources


More Information
================


Synthesis and Configuration
---------------------------
- RTL Simulation
  - Testbench.vhdl:          Generic map of entity Testbench
  - Testbench_rtl_conf.vhdl: Configuration for the UART module
  - Need to select Project/Manual compile order
- Synthesis
  - Define the Generics in Synthesis options
    Left Bar/Implement Design/Synthesize/Right Click Process Properties
  - Must match the RTL simulation settings
  - Unselect Project/Manual compile order
- POST Simulation
  - Testbench.vhdl:  Generic map of entity Testbench
  - Unselect Project/Manual compile order


Optimizing UART receiver
------------------------
I forked the UART module from https://github.com/pabennett/uart and
played around with it. My goal was to improve the code for implementation
in the Xilinx CoolRunner CPLD. My hope is that this will also reduce the
resource usage in FPGA devices.

The timing did not changed at all and stayed at clk_max = 454.545 MHz

Implementation results with the default strategy are listed for every step:

1. Original:
    ./: 2140ab3c85a2ec667ca99fb4756176e8e75bfb1b
    src/ext-uart/: eec287ccddf2afae7a0932f2c4f57be80694e2e8
    |Macrocells     |Product Terms    |Function Block   |Registers      |Pins          |
    |Used/Tot       |Used/Tot         |Inps Used/Tot    |Used/Tot       |Used/Tot      |
    |229/256 ( 89%) |458 /896  ( 51%) |472 /640  ( 74%) |178/256 ( 70%) |20 /118 ( 17%)|
1. Reduced Baud Counters, RX Sample in Data Bit Midpoint
    ./: 2140ab3c85a2ec667ca99fb4756176e8e75bfb1b
    src/ext-uart/: 7c584809500da0dbf8780ec23d0d22374dcda4f0
    |Macrocells     |Product Terms    |Function Block   |Registers      |Pins          |
    |Used/Tot       |Used/Tot         |Inps Used/Tot    |Used/Tot       |Used/Tot      |
    |164/256 ( 64%) |339 /896  ( 38%) |376 /640  ( 59%) |119/256 ( 46%) |20 /118 ( 17%)|
1. Intermediate Baud Counter Signal for comparision baud_counter = 0
    No difference to above, so do not commit
1. uart_tx_count as 3-bit integer, change data sending from index into uart_tx_data_block to shift operation
    ./: 2140ab3c85a2ec667ca99fb4756176e8e75bfb1b
    src/ext-uart/: ad7a2e3db93830aa9d62ac3afeedd80c43ec6af6
    |Macrocells     |Product Terms    |Function Block   |Registers      |Pins          |
    |Used/Tot       |Used/Tot         |Inps Used/Tot    |Used/Tot       |Used/Tot      |
    |124/256 ( 48%) |277 /896  ( 31%) |231 /640  ( 36%) |90 /256 ( 35%) |20 /118 ( 17%)|
1. uart_rx_count as 3-bit integer, change receiving data from index into uart_rx_data_block to shift operation
    ./: 2140ab3c85a2ec667ca99fb4756176e8e75bfb1b
    src/ext-uart/: 933c7355dee84d16a97abdd969dd9fd8122785cb
    |Macrocells     |Product Terms    |Function Block   |Registers      |Pins          |
    |Used/Tot       |Used/Tot         |Inps Used/Tot    |Used/Tot       |Used/Tot      |
    |79 /256 ( 31%) |190 /896  ( 21%) |112 /640  ( 17%) |61 /256 ( 24%) |20 /118 ( 17%)|
1. Receive: Remove separate waiting state rx_send_block until data is fetched from system
    ./: 2140ab3c85a2ec667ca99fb4756176e8e75bfb1b
    src/ext-uart/: f0c1d74bea214b1a553e2dc5dca0cc8ae2c97341
    |Macrocells     |Product Terms    |Function Block   |Registers      |Pins          |
    |Used/Tot       |Used/Tot         |Inps Used/Tot    |Used/Tot       |Used/Tot      |
    |77 /256 ( 30%) |179 /896  ( 20%) |110 /640  ( 17%) |60 /256 ( 23%) |20 /118 ( 17%)|
1. CPLD Optimization: Use GSR (global async reset) by changing SYNC Reset to ASYNC reset
    ./: dde5c2f403615b33d83364c684ab829a46dc4cdb
    src/ext-uart/: a83a069cf661cf6638025fa79373a4cddd4aff69
    |Macrocells     |Product Terms    |Function Block   |Registers      |Pins          |
    |Used/Tot       |Used/Tot         |Inps Used/Tot    |Used/Tot       |Used/Tot      |
    |77 /256 ( 30%) |129 /896  ( 14%) |100 /640  ( 16%) |58 /256 ( 23%) |20 /118 ( 17%)|


Pull requests are pending/will be prepared soon.



UART/RS232 Protocol
-------------------
http://en.wikipedia.org/wiki/Asynchronous_serial_communication
