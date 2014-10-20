include ../Makefile.include

PROGRAM = main
FIRMWARE = $(PROGRAM).hex

LDFLAGS += -L$(PROJECT_ROOT)/sys -lsys
LDFLAGS += -Tgcc_nrf51_s110_xxaa.ld
LDFLAGS += -L$(PROJECT_ROOT)/lib -lapp
LDFLAGS += -L$(PROJECT_ROOT)/ble -lble

OBJECTS = \
	  main.o \
	  qrsdet2.o \
	  qrsfilt.o \

$(FIRMWARE): $(PROGRAM)
	$(CP) $< $@

$(PROGRAM): $(OBJECTS)
	$(CC) $(ARCH_FLAGS) $(OBJECTS) $(LDFLAGS) -o $@

.PHONY: flash flashclean

flash: $(FIRMWARE)
	JLinkGDBServer -device nRF51822 -speed 1000 -if SWD &
	sleep 2
	$(DB) --command=flash -batch
	sleep 2
	pkill JLinkGDBServer

flashclean:
	JLinkGDBServer -device nRF51822 -speed 1000 -if SWD &
	sleep 2
	$(DB) --command=flashclean -batch
	sleep 2
	pkill JLinkGDBServer

clean:
	-rm -rf *~ *.o $(PROGRAM).hex $(PROGRAM)
