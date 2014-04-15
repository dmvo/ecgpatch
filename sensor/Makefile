SYSDIRS = ble lib sys src

.PHONY: sysdirs $(SYSDIRS)

sysdirs: $(SYSDIRS)

$(SYSDIRS):
	$(MAKE) -C $@

clean:
	for dir in $(SYSDIRS); do \
		$(MAKE) -C $$dir clean; \
	done
	-rm -rf *~
