# Reading from a Disk
So, we learned how to run a simple operating system from the boot sector. Using the legacy boot, the first 512 bytes of the disk are read as the boot sector and loaded into memory in order to execute. This is fine for a small program, but soon we will run out of space for running our operating system. This means we will need to access disk space beyond the boot sector. This is where disk reading is useful.

The portion of the operating system stored in the boot sector is often called the **bootloader**, while other portions of the operating system across the disk is called the **kernel**.

#### Bootloader
- Loads basic components into memory
- Puts system in expected state
- Collects information about system
- Starts in 16-bit real mode
  - After switching to 32-bit protected mode, access to BIOS functionality is lost

## Floppy Disks
For storing the kernel, I will use a floppy disk storage system. This is because of the universal support on most architectures, and the FAT12 file system which is rather simple. In order to accomodate this, some changes were made to the `Makefile`. We added separate targets for building the kernel and bootloader binaries, and also changed the image to be built with a FAT12 file system. One thing to note is that the FAT12 file system requires that certain information be present at the start of the disk, so our previous method of starting the bootloader at the beginning of the disk will not work. This can actually be easily fixed however, as we can just add the necessary information to the start of our bootloader program. The first 3 bytes must disassemble to `JMP SHORT 3C NOP`. Next is the version of DOS, of which I will use `MSWIN4.1` for compatibility. After that is the bytes per sector, which is 512 for a standard floppy disk. There is also sectors per cluster, reserved sectors, FAT table count, number of directory entries, total number of sectors, media descriptor type, number of sectors per FAT, number of sectors per track, head count, hidden sector count and large sector count. This is the configuration I added before my main function:

```assembly
;
; FAT12 HEADER
;
jmp short start
nop

bdb_oem:			db "MSWIN4.1"	; 8 bytes
bdb_bytes_per_sector:		dw 512
bdb_sectors_per_cluster:	db 1
bdb_reserved_sectors:		dw 1
bdb_fat_count:			db 2
bdb_dir_entries_count:		dw 0xe0
bdb_total_sectors:		dw 2880			; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:	db 0xf0			; F0 = 3.5" floppy disk
bdb_sectors_per_fat:		dw 9			; 9 sectors/FAT
bdb_sectors_per_track:		dw 18
bdb_heads:			dw 2
bdb_hidden_sectors:		dd 0
bdb_large_sector_count:		dd 0
```