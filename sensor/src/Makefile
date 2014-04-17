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

clean:
	-rm -rf *~ *.o $(PROGRAM).hex $(PROGRAM)
