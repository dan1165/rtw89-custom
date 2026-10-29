# SPDX-License-Identifier: GPL-2.0 OR BSD-3-Clause
#
# Build the custom rtw89 (RTL8851BU) modules against the running kernel.
#   make            build
#   make clean      remove build output
#
# Load/unload is deliberately not wired up here; see README.md.

KDIR ?= /lib/modules/$(shell uname -r)/build
SRC  := $(CURDIR)/src

all:
	$(MAKE) -C $(KDIR) M=$(SRC) modules

clean:
	$(MAKE) -C $(KDIR) M=$(SRC) clean

.PHONY: all clean
