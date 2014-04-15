include ../Makefile.include

PROGRAM = main

LDFLAGS = -L$(PROJECT_ROOT)/sys -lsys
LDFLAGS += -L$(PROJECT_ROOT)/lib -lapp
LDFLAGS += -L$(PROJECT_ROOT)/ble -lble
LDFLAGS += -Tgcc_nrf51_s110_xxaa.ld

OBJECTS = \
	  main.o \
	  qrsdet2.o \
	  qrsfilt.o \

$(PROGRAM): $(OBJECTS)
	$(CC) $(OBJECTS) $(LDFLAGS) -o $@

clean:
	-rm -rf *~ *.o $(PROGRAM)
