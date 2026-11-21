#
# Copyright (C) 2025 Sylas Hollander.
# PURPOSE: Makefile for Apple TV bare-metal programs
# SPDX-License-Identifier: MIT
#

# If the generation of headers is parallelized, they will likely not exist or be corrupted by the time Clang gets to them
.NOTPARALLEL: kernel_bin.h initramfs_bin.h

# Check what OS we're running. Should work on Linux and macOS.
OSTYPE = $(shell uname)

# Target defs for Linux cross compiler.
TARGET = i386-apple-darwin8

# Definitions for compiler
CC := clang

# Definitions for linker
ifeq ($(OSTYPE),Linux)
	LD := /opt/cross/bin/$(TARGET)-ld
else
	LD := ld
endif

# Flags for mach-o linker
LDFLAGS := 	-static \
           	-segalign 0x1000 \
           	-segaddr __TEXT 0x00100000 \
           	-sectalign __TEXT __text 0x1000 \
           	-sectalign __DATA __common 0x1000 \
           	-sectalign __DATA __bss 0x1000 \

DEFINES :=
ifdef INITRAMFS
	DEFINES += -DINITRAMFS
endif

CFLAGS := -Wall -Werror -nostdlib -fno-stack-protector -fno-builtin -O0 -std=gnu11 --target=$(TARGET) -Iinclude $(DEFINES)

OBJS := start.o atvlib.o baselibc_string.o cons.o tinyprintf.o debug.o linux.o e820.o

all: kernel_bin.h initramfs_bin.h mach_kernel

# Record the kernel and initramfs contents so the headers are regenerated whenever either changes, even when switching
# to a different file with an older timestamp
ifdef KERNEL
kernel.stamp: FORCE
	@sha1sum $(KERNEL) $(INITRAMFS) | cmp -s - $@ || sha1sum $(KERNEL) $(INITRAMFS) > $@
else
kernel.stamp:
	$(error No kernel file specified. Specify one by appending KERNEL=/path/to/kernel)
endif

# Add kernel to executable
kernel_bin.h: kernel.stamp
	xxd -n kernel_bin -i $(KERNEL) > $@
initramfs_bin.h: kernel.stamp
ifdef INITRAMFS
	xxd -n initramfs_bin -i $(INITRAMFS) > $@
else
	$(warning No initramfs/initrd file specified. Specify one by appending INITRAMFS=/path/to/initramfs if you want.)
endif

linux.o: kernel_bin.h $(if $(INITRAMFS),initramfs_bin.h)

%.o: %.S
	$(CC) $(CFLAGS) -c $< -o $@
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@
mach_kernel: $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $@
# Note: header generation must run before compilation

# Boot files and installer downloads for the USB images
DL := downloads
ATV_DMG_URL := https://mesu.apple.com/data/OS/061-7495.20100210.TAVfr/2Z694-6013-013.dmg
ATV_DMG_SHA1 := 97623d8d21bb59b0f4dc9d1b1c037f25c9fe09c3
DUMMY_KEXT_URL := https://github.com/DistroHopper39B/DummyKext/releases/download/1.0/Dummy.kext.zip
DEBIAN_INSTALLER_URL := https://deb.debian.org/debian/dists/bookworm/main/installer-i386/current/images/netboot/debian-installer/i386
# Use GPT so the boot partition can be flagged atvrecv, and skip GRUB since boot.efi does the booting
INSTALLER_FLAGS := partman-partitioning/default_label=gpt grub-installer/skip=true

USB_IMAGE ?= atv-usb.img

$(DL)/boot.efi:
	mkdir -p $(DL)
	wget -O $(DL)/atv.dmg $(ATV_DMG_URL)
	echo "$(ATV_DMG_SHA1)  $(DL)/atv.dmg" | sha1sum -c -
	7z e -y -o$(DL) $(DL)/atv.dmg OSBoot/System/Library/CoreServices/boot.efi
	rm $(DL)/atv.dmg

$(DL)/Dummy.kext:
	mkdir -p $(DL)
	wget -O $(DL)/Dummy.kext.zip $(DUMMY_KEXT_URL)
	7z x -y -o$(DL) $(DL)/Dummy.kext.zip
	rm -f $(DL)/Dummy.kext.zip $(DL)/Dummy.kext/.DS_Store

$(DL)/debian-installer/%:
	mkdir -p $(@D)
	wget -O $@ $(DEBIAN_INSTALLER_URL)/$*

# USB image that boots mach_kernel; set the kernel command line with KERNEL_FLAGS="..."
usb-image: mach_kernel $(DL)/boot.efi $(DL)/Dummy.kext
	./mkusbimage.sh $(USB_IMAGE) $(DL)/boot.efi $(DL)/Dummy.kext mach_kernel com.apple.Boot.plist "$(KERNEL_FLAGS)"

# USB image that boots the Debian 12 netboot installer
installer-usb-image: $(DL)/debian-installer/linux $(DL)/debian-installer/initrd.gz
	$(MAKE) usb-image KERNEL=$(DL)/debian-installer/linux INITRAMFS=$(DL)/debian-installer/initrd.gz \
		KERNEL_FLAGS="$(INSTALLER_FLAGS)" USB_IMAGE=atv-installer.img

clean:
	rm -f initramfs_bin.h kernel_bin.h kernel.stamp *.o mach_kernel

distclean: clean
	rm -rf $(DL) *.img

FORCE:

.PHONY: all clean distclean usb-image installer-usb-image FORCE
.DELETE_ON_ERROR: