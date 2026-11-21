# Modern Linux on the Original Apple TV
This bootloader will allow you to boot Linux on an Apple TV (1st generation) and Intel Macs with 32-bit EFI (though for
all but the MacBook2,1 consider using UEFI GRUB). Unlike [atv-bootloader](https://github.com/davilla/atv-bootloader) this
bootloader will compile with modern Clang and boot distributions with giant ramdisks such as [Debian](https://debian.org).

## How this loader works
The original Apple TV is an EFI-based machine like Intel Macs, but can only boot Apple EFI files. 

## Installing this on your Apple TV
**Note: Due to Linux's superior handing of GPT disks with non-standard partition types I highly recommend setting this
up on Linux.**

### Installing Linux
Use a VM to install a 32-bit Linux distro (I recommend Alpine Linux, but Debian will work too). Image it
over to (or directly install it to) either a USB flash drive or IDE hard drive.

### Formatting the USB/Hard Drive (this should be done on Linux)
* Install [GParted](https://gparted.org/) for your distro.
* Connect a USB drive to your computer.
* Open GParted and select your USB drive.
* Resize the existing Linux partition. 
* Go to `Partition -> New`. Set the filesystem to `fat32` and the label to `boot`.
* Apply the changes.
* Select your new partition and go to `Partition -> Flags`, then check the `atvrecv` box.
* Close GParted. The new partition should show up in your file manager's device list. If it doesn't, disconnect and
reconnect it.

### Build `linux-loader-appletv`
#### Docker (macOS or Linux)
* Install Docker (Docker Desktop, OrbStack, etc.)
* Clone this repo and `cd` into it
* Type `./docker-make.sh KERNEL=/path/to/vmlinuz INITRAMFS=/path/to/initrd`. The first run builds a container with
Clang and cctools-port, which takes a few minutes.

`./docker-make.sh` runs `make` in the container, so the other targets work through it too. `usb-image` builds
`atv-usb.img`, a complete bootable disk image containing the boot partition (`boot.efi` and `Dummy.kext` are downloaded
for you). Set the kernel command line with `KERNEL_FLAGS="..."`, then write the image to a USB drive (`diskutil list` on
macOS to find it, `/dev/sdX` on Linux):
```
./docker-make.sh KERNEL=/path/to/vmlinuz INITRAMFS=/path/to/initrd usb-image KERNEL_FLAGS="root=UUID=... ro"
sudo dd if=atv-usb.img of=/dev/rdiskN bs=4m
```

#### macOS
**Note: current Xcode versions refuse to link i386 (`ld: linking for i386 is no longer supported`). If you get this
error, use Docker instead.**
* Install the Xcode CLI tools: `xcode-select --install`
* Clone this repo and `cd` into it
* Type `make KERNEL=/path/to/vmlinuz INITRAMFS=/path/to/initrd`, using the paths to the Linux kernel and initramfs from
the installation you just made (ignore any warnings about deprecated 32-bit support)

#### Linux
* Install Clang, autoconf, automake, and libtool
* Compile version 986 of [cctools-port](https://github.com/tpoechtrager/cctools-port) (newer versions work but are more
complicated to set up)
```
git clone https://github.com/tpoechtrager/cctools-port.git -b 986-ld64-711
cd cctools-port/cctools
./configure --prefix=/opt/cross --target=i386-apple-darwin8
make -j$(nproc)
sudo make install
```
* Clone this repo and `cd` into it
* Type `make KERNEL=/path/to/vmlinuz INITRAMFS=/path/to/initrd`, using the paths to the Linux kernel and initramfs from
the installation you just made (ignore any warnings about `/System/Library/Frameworks`)
#### Windows
Use WSL or a VM or something, I don't know. Or just dual boot Linux.

### Gather and copy necessary files (This should be done on Linux)
* `boot.efi`:
  * Install `p7zip`
  * Download an Apple TV update image: `wget https://mesu.apple.com/data/OS/061-7495.20100210.TAVfr/2Z694-6013-013.dmg`
    (~235MB in size, SHA-1 hash of `97623d8d21bb59b0f4dc9d1b1c037f25c9fe09c3`)
  * Extract `boot.efi` from the image: `7z e 2Z694-6013-013.dmg OSBoot/System/Library/CoreServices/boot.efi`
  * Copy `boot.efi` to the boot partition you just created on the USB drive
* `Dummy.kext`:
  * Grab `Dummy.kext.zip` from https://github.com/DistroHopper39B/DummyKext/releases and extract it
  * On the boot partition on the USB drive, create the `System/Library/Extensions` folders
  * Copy `Dummy.kext` to the `Extensions` folder you just created
* Copy `com.apple.Boot.plist` and `mach_kernel` to the root of the partition

### Configure the kernel parameters
In order to tell Linux what disk to boot from, among other things, you'll need to copy the kernel parameters from the
stock bootloader to this one. These parameters are usually stored in `/boot/grub/grub.cfg` or `/boot/syslinux/syslinux.cfg`.
Find the line with `root=UUID=` or something like that, and copy everything after the path to the Linux kernel. Paste it
into the `Kernel Flags` key in `com.apple.Boot.plist`.

With all of this done, turn on your Apple TV and Linux should boot!

## Installing Debian directly on the Apple TV
This installs Debian 12 to the internal drive by booting the Debian installer from USB, so the Apple TV never has to be
opened. **This erases the internal drive.** You'll need Docker, a USB drive, a powered USB hub (the Apple TV has a single
USB port, and the installer needs a keyboard plugged in at the same time as the drive), a USB keyboard, Ethernet and a
display.

This procedure has been tested on an Apple TV (AppleTV1,1) with its IDE drive replaced by a 128GB SSD.

### Which Debian
Debian 12 (bookworm) is the last Debian release with a 32-bit x86 kernel. Debian 13 and sid still build i386 packages,
but only as a multiarch userland: there is no `linux-image-686` or `linux-image-686-pae` and no installer. Debian 12 is
supported (including LTS) until mid-2028.

### Make the installer USB drive
* `./docker-make.sh installer-usb-image` downloads the Debian netboot installer, `boot.efi` and `Dummy.kext` and builds
`atv-installer.img`, with kernel flags that make the installer use a GPT partition table and skip GRUB
* Write it to the USB drive. On macOS, find the drive with `diskutil list`, then:
```
diskutil unmountDisk /dev/diskN
sudo dd if=atv-installer.img of=/dev/rdiskN bs=4m
```

### Boot the installer
* Plug the USB drive and keyboard into the hub, connect Ethernet and the display, and turn on the Apple TV. It boots
from the USB drive's `atvrecv` partition in preference to the internal drive.
* You may briefly see a "?" while the firmware waits for the USB drive to come up behind the hub. After that the Apple
logo stays up for a minute or two while `boot.efi` reads the 36MB `mach_kernel` over USB.

### Install
With only 256MB of RAM the installer runs in low memory mode, which skips loading a lot of drivers. Expect to help it
along:
* When asked which modules to load for the disk, choose `ata_piix` (the Apple TV's IDE controller) and `sd_mod`
* When asked for the missing firmware `b43-open/ucode11.fw`, answer No. It's for the Broadcom Wi-Fi card, which isn't
needed for an Ethernet install.
* Before partitioning, switch to a shell (Alt-F2) and run `modprobe ext4`, otherwise ext4 isn't offered as a file system
* The installer has no way to create a FAT32 file system (no `mkfs.vfat`, and BusyBox doesn't have it either), so the
boot partition is created now but formatted after the first boot

Device names aren't stable: depending on module load order the internal drive can be `sda` or `sdb`. Go by the size and
model shown in the partitioner, or `blkid` in the shell.

Partition the internal drive manually:
* Select the drive itself and create a new empty partition table. If the drive still has tvOS partitions, don't reuse
them: the installer keeps their old file systems and fails the file system check.
* Create, in this order:
  1. 256MB, use as: do not use (this becomes the boot partition)
  2. 1GB, swap
  3. the rest, ext4, mounted at `/`
* In software selection, choose SSH server and standard system utilities
* The installer warns that no boot loader was installed; continue
* Before finishing the installation, switch to the shell and copy the installed kernel, initramfs and root file system
UUID to the USB drive (replace `sdX3` with the internal drive's root partition):
```
modprobe vfat
mkdir -p /stick && mount -t vfat "$(blkid -L BOOT)" /stick
cp /target/boot/vmlinuz-* /target/boot/initrd.img-* /stick/
blkid /dev/sdX3 > /stick/root-uuid.txt
umount /stick
```
* Finish the installation and turn the Apple TV off when it reboots

The installer may have installed a newer kernel from the security updates alongside its own, in which case there are
two of each file. Use the newest.

### Boot the installed system from USB
macOS can't mount the USB drive (it doesn't mount the Apple TV recovery partition type, and current macOS can't load its
old FAT driver with `mount`), so copy the partition into a file and extract the files with the build container:
```
sudo dd if=/dev/rdiskNs1 of=stick-part.img bs=4m
docker run --rm --user "$(id -u):$(id -g)" -e MTOOLS_SKIP_CHECK=1 -v "$PWD:/src" atv-linux-loader-build \
    mcopy -n -i stick-part.img '::/vmlinuz-*' '::/initrd.img-*' ::/root-uuid.txt .
```
Then build a USB image for the installed system, using the UUID from `root-uuid.txt`, and write it to the USB drive:
```
./docker-make.sh KERNEL=vmlinuz-... INITRAMFS=initrd.img-... usb-image KERNEL_FLAGS="root=UUID=... ro"
sudo dd if=atv-usb.img of=/dev/rdiskN bs=4m
```
Boot the Apple TV from the USB drive. It should come up to a login prompt, and SSH works if you selected it.

### Move booting to the internal drive
Log in, become root with `su -` (plain `su` leaves `/usr/sbin` off the `PATH`, so `mkfs.vfat`, `parted` and `blkid`
aren't found), and set up the boot partition. Here `sdX` is the internal drive and `sdY` is the USB drive; check with
`lsblk`.
```
apt install -y dosfstools parted
mkfs.vfat -F 32 -n ATVBOOT /dev/sdX1
parted -s /dev/sdX set 1 atvrecv on
mkdir -p /boot/atv
echo "UUID=$(blkid -s UUID -o value /dev/sdX1) /boot/atv vfat defaults,nofail 0 2" >> /etc/fstab
systemctl daemon-reload && mount /boot/atv
mkdir -p /mnt/stick && mount /dev/sdY1 /mnt/stick
cp -r /mnt/stick/. /boot/atv/ && umount /mnt/stick
```
Power off, remove the USB drive and power on. The Apple TV now boots from the internal drive. Keep the USB drive: booting
from it is the way back in if the internal boot partition breaks.

### Kernel updates
The kernel and initramfs are built into `mach_kernel`, so a kernel update from `apt` isn't used until `mach_kernel` is
rebuilt with the new kernel and initramfs and copied to `/boot/atv`. Until then the Apple TV keeps booting the old
kernel, which keeps working as long as its package isn't removed; don't `apt autoremove` it, or its modules go away.

## Configuring the Boot Process (`com.apple.Boot.plist`)
Boot-time configuration is done within the [com.apple.Boot.plist](com.apple.Boot.plist) file. The following
keys are defined within this file:

`Background Color`: Controls the background color. This is a 24-bit RGB value that must stored in decimal form, meaning
that 0 is black and 16777215 (0xFFFFFF) is white. If you completely remove this key, the default Apple grey is used.

`Boot Logo`: This is an image file displayed on the boot screen. If you completely remove this key, a grey Apple logo is
shown.

`Kernel`: This is the name of the kernel file to be loaded by `boot.efi`. `mach_kernel` is the default name.

`Kernel Flags`: This is the command line text sent to the Linux kernel. Its maximum length is 1024 bytes.

