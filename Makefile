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

# apply / revert. The in-tree modules use the same names, so they go first.
load:
	-sudo modprobe -r rtw89_8851bu rtw89_8851b rtw89_usb rtw89_core
	# modprobe -r takes the mac80211/cfg80211 deps with it; insmod does not
	# resolve dependencies, so put them back first
	sudo modprobe mac80211 cfg80211
	sudo insmod src/rtw89_core.ko $(RTW89_ARGS)
	sudo insmod src/rtw89_usb.ko
	sudo insmod src/rtw89_8851b.ko
	sudo insmod src/rtw89_8851bu.ko

unload:
	-sudo rmmod rtw89_8851bu
	-sudo rmmod rtw89_8851b
	-sudo rmmod rtw89_usb
	-sudo rmmod rtw89_core

.PHONY: all clean load unload
