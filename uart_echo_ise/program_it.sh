#!/bin/bash
# Program the Coolrunner II Starter Board
# You need the Digilent Adept Software from
# http://www.digilentinc.com/Products/Detail.cfm?Prod=ADEPT2

djtgcfg --verbose erase -d Cr2s2 --index 0
djtgcfg --verbose prog -d Cr2s2 --index 0 -f uart_echo_ise.jed
