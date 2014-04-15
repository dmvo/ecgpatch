include ../Makefile.include

OBJECTS = gcc_startup_nrf51.o \
	  softdevice_handler.o \
	  system_nrf51.o \

libs: libsys.a($(OBJECTS))

clean:
	-rm -rf lib*.a *.o *~
