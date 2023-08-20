# Reading from a Disk
So, we learned how to run a simple operating system from the boot sector. Using the legacy boot, the first 512 bytes of the disk are read as the boot sector and loaded into memory in order to execute. This is fine for a small program, but soon we will run out of space for running our operating system. This means we will need to access disk space beyond the boot sector. This is where disk reading is useful.

The portion of the operating system stored in the boot sector is often called the **bootloader**, while other portions of the operating system across the disk is called the **kernel**.

#### Bootloader
- Loads basic components into memory
- Puts system in expected state
- Collects information about system
- Starts in 16-bit real mode
  - After switching to 32-bit protected mode, access to BIOS functionality is lost

Starting from now, the bootloader will be kept in a separate folder than the kernel. For now, we will focus on getting the bootloader to read from the disk so that code beyond the boot sector can be loaded into memory and executed.

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
bdb_dir_entries_count:		dw 0e0h
bdb_total_sectors:		dw 2880		; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:	db 0f0h		; F0 = 3.5" floppy disk
bdb_sectors_per_fat:		dw 9		; 9 sectors/FAT
bdb_sectors_per_track:		dw 18
bdb_heads:			dw 2
bdb_hidden_sectors:		dd 0
bdb_large_sector_count:		dd 0

```

After that, we need to place the extended boot record. THis includes the drive number, a reserved byte, a signature of `0x28` or `0x29`, the volume ID (4 byte), the volume label (11 bytes), and the system ID (8 bytes) which should be `FAT12` padded with spaces. This is what my EBR looks like:

```assembly
; Extended boot record
ebr_drive_number:			db 0			; 0x00 floppy, 0x80 hdd, useless
					db 0			; Reserved
ebr_signature:				db 29h
ebr_volume_id:				db 12h, 34h, 56h, 78h	; Serial number, value doesn't matter
ebr_volume_label:			db "NINJOSH OS "	; 11 bytes, padded with spaces
ebr_system_id:				db "FAT12"		; 8 bytes
```

## Disk Layout
Now that our file system is setup, we need to know how to access different parts of the disk. Each disk has a column of plates referred to as **platters**. Each of these platters have 2 shafts, with a piece of metal at the head called the **head**. In traditional disks, this heads moves along the surface of the disk and translates the magnetic field into an electric current, reading from the disk. It can also write to the disk by supplying an electric current. Each platter can be divided into concentric circles called **tracks/cylinders**, and triangluar slices of the platter are called **sectors**. The head is allowed to move across the surface of the rotating platter to access different track and sector combinations. This is why different parts of the disk can be accessed using a **cylinder #**, **head #**, and **sector #**. This is called the **cylinder head sector (CHS) addressing scheme**.

![Disk diagram](./images/10_01_DiskMechanism.jpg)

This scheme works, but is rather complicated for us, as we don't really need to worry about the physical locations of our data, but rather where our data is logically on the disk (beginning, middle, end). For this we can use the **logical block addresssing (LBA) scheme**. With this, only one number is needed to reference a block on the disk. Unfortunately, our BIOS only supports CHS addressing, so we will need to develop the conversion ourselves.

### LBA to CHS Conversion
In the CHS addressing scheme, cylinder and head indices start at 0, but the sector index starts at 1. We know the number of sectors per track/cylinder and the number of heads per cylinder. In logical block order, the sector increases by 1 each time, eventually resetting to 1. After going through all sectors in the cylinder-head group, the head is then increased, eventually resetting to 0. After going through all sectors in that cylinder, the cylinder is then increased. Using this we can achieve the following equations:

```
sector = (LBA % sectors per track) + 1
head = (LBA / sectors per track) % heads
cylinder = (LBA / sectors per track) / heads
```

Using this, we can write an assembly function as follows:

```assembly
;
; Converts an LBA address to a CHS address
; Params:
;	- ax: LBA address
; Returns:
;	- cx [bits 0-5]: sector number
;	- cx [bits 6-15]: cylinder number
;	- dh: head number
;
lba_to_chs:
	push ax
	push dx

	xor dx, dx				; dx = 0
	div word [bdb_sectors_per_track]	; ax = LBA / sectors per track
						; dx = LBA % sectors per track

	inc dx					; dx = LBA % sectors per track + 1 = sector number
	mov cx, dx				; cx = sector number

	xor dx, dx
	div word [bdb_heads]			; ax = (LBA / sectors per track) / heads = cylinder number
						; dx = (LBA / sectors per track) % heads = head number
	mov dh, dl 			        ; dh = head
	mov ch, al				; ch = cylinder (lower 8 bits)
	shl ah, 6
	or cl, ah				; Put upper 2 bits of cylinder in CL
	
	pop ax
	mov dl, al				; Restore dl
	pop ax
	ret
```
Now that the conversion is done, we can read a logical block from the disk. Given an LBA address, the number of sectors to read, the drive number, and the location to store the read data, we can write the following function:

```assembly
;
; Reads sectors from a disk
; Params:
;	- ax: LBA address
;	- cl: Number of sectors to read (up to 128)
;	- dl: Drive number
;	- es:bx: Memory address to store read data
;
disk_read:
	push ax				; Save registers we will modify
	push bx
	push cx
	push dx
	push di

	push cx				; Temporarily save cl
	call lba_to_chs			; Compute CHS
	pop ax				; al = number of sectors to read

	mov ah, 02h
	mov di, 3			; Retry count

.retry:
	pusha				; Save all registers, we don't know what BIOS does
	stc 				; Set carry flag, some BIOSes don't set it
	int 13h				; Carry flag cleared = success
	jnc .done			; Jump if carry not set

	; Read failed
	popa
	call disk_reset

	dec di
	test di, di
	jnz .retry

.fail:
	; All attempts are exhausted
	jmp floppy_error

.done:
	popa

	pop di				; Restore registers modified
	pop dx
	pop cx
	pop bx
	pop ax
	ret

;
; Resets disk controller
; Params:
;	- dl: Drive number
;
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret
```

In our simulation, the disk is not likely to fail. For realistic floppy disks, the chance of a read failure is rather high, and as such the documentation suggests attempting to read at least 3 times. This is why there is a retry block for the actual disk read. If the disk fails to be read 3 times, then an error function is jumped to, which will print a message about the disk failure.

```assembly
;
; Error handlers
;
floppy_error:
	mov si, msg_read_failed
	call puts
	jmp wait_key_and_reboot

wait_key_and_reboot:
	mov ah, 0
	int 16h						; Wait for key press
	jmp 0ffffh:0				; Jump to beginning of BIOS, should reboot

.halt:
	cli
	hlt

...

msg_hello: 				db "Hello world!", ENDL, 0
msg_read_failed: 		db "Read from disk failed!", ENDL, 0
```

And with that, we can add our disk read function to the main.

```assembly
main:
	; Set up data segments
	mov ax, 0				; Can't write to ds/es directly
	mov ds, ax
	mov es, ax

	; Setup stack
	mov ss, ax
	mov sp, 0x7c00				; Stack grows downwards from where we are loaded in memory

	; Read something from floppy disk
	; BIOS should set dl to drive number
	mov [ebr_drive_number], dl

	mov ax, 1				; LBA = 1, second sector from disk
	mov cl, 1				; 1 sector to read
	mov bx, 0x7e00				; Data should be after the bootloader
	call disk_read

	; Print message
	mov si, msg_hello
	call puts

	cli
	hlt
```

Notice how the `hlt` statements have an extra command before them: `cli`. This is just so interrupts are disabled, meaning that when the `hlt` instruction is reached, the CPU will not be able to handle the interrupt and return to the program. It is also important to note where the data is being read to. It is loaded into memory at `0x7e00`, which comes after the bootloader in memory. If we run the bootloader and check the disk, we can see that 1 sector of data gets read into the space directly after the bootloader.

![floppy disk after disk read](./images/Screenshot%20from%202023-08-19%2023-22-59.png)

Congratulations, you can now read from the disk!

[Table of Contents](../README.md)

[Previous - Hello World!](../hello_world/README.md)

[Next - Reading from a Disk](../disk_reading/README.md)