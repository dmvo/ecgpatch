ecgpatch
========

This repository contains source code related to the ECG patch
developed in Helsinki Metropolia University of Applied Sciences
in the context of the HealthSens project.

The code is published under a permissive license and it is
good to use as a basis for similar research projects or even
serve as a basis for commercial products. In the latter case
we ask to be contacted prioir to use.

Note that not all files in this repository are covered with
Helsinki Metropolia University of Applied Sciences copyright.
Some are from the chip vendor, for example, in which case
there is a note about this in the file itself. Refer to
the vendor license when copying and using such files.

The source layout is as follows:

board/ : contains Eagle files for the schematics and PCB

ios-new/ : sources of the iPhone/iPad app to read data
  from the sensir patch
  
ios/ : legacy iOS code, don't look there

sensor/ : nRF51 firmware for the ECG patch.

Build instructions
==================

Please follow the usual XCode build procedure to build the iOS app.
You need to have a valid developer license from Apple in order to
be able to work with the code.

Firmware should be built by issuing the `make' command in the `sensor'
subdirectory. It is expected that you have an ARM cross-compiler.
We have successfully used gcc version 4.7.3 (20130312), however
another, more recent, compiler should be suitable. Probably you
will need to edit the `Makefile.include' file to reflect your
settings such as project root directory and optimization options.

When build is complete, use the .hex file in the `src' subdirectory
to flash the nRF51 chip. The `flash' target in the Makefile will
help you do this provided you have set up the gdb and JLinkGDBServer
properly. Refer to the documentation of respective components for
details.
