org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A

;
; FAT12 HEADER
;
jmp short start
nop

bdb_oem:					db "MSWIN4.1"			; 8 bytes
bdb_bytes_per_sector:		dw 512
bdb_sectors_per_cluster:	db 1
bdb_reserved_sectors:		dw 1
bdb_fat_count:				db 2
bdb_dir_entries_count:		dw 0e0h
bdb_total_sectors:			dw 2880					; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:	db 0f0h					; F0 = 3.5" floppy disk
bdb_sectors_per_fat:		dw 9					; 9 sectors/FAT
bdb_sectors_per_track:		dw 18
bdb_heads:					dw 2
bdb_hidden_sectors:			dd 0
bdb_large_sector_count:		dd 0

; Extended boot record
ebr_drive_number:			db 0					; 0x00 floppy, 0x80 hdd, useless
							db 0					; Reserved
ebr_signature:				db 29h
ebr_volume_id:				db 12h, 34h, 56h, 78h	; Serial number, value doesn't matter
ebr_volume_label:			db "NINJOSH OS "		; 11 bytes, padded with spaces
ebr_system_id:				db "FAT12   "			; 8 bytes

start:
	jmp main


;
; Prints a string to the screen
; Params:
;	- ds:si points to string
puts:
	; Save registers we will modify
	push si
	push ax
	push bx

.loop:
	lodsb						; Loads next character in al
	or al, al					; Verify if next character is null?
	jz .done

	mov ah, 0x0e				; Call bios interrupt
	mov bh, 0
	int 0x10

	jmp .loop

.done:
	pop bx
	pop ax
	pop si
	ret


main:
	; Set up data segments
	mov ax, 0					; can't write to ds/es directly
	mov ds, ax
	mov es, ax

	; Setup stack
	mov ss, ax
	mov sp, 0x7c00				; Stack grows downwards from where we are loaded in memory

	; Read something from floppy disk
	; BIOS should set dl to drive number
	mov [ebr_drive_number], dl

	mov ax, 1					; LBA = 1, second sector from disk
	mov cl, 1					; 1 sector to read
	mov bx, 0x7e00				; Data should be after the bootloader
	call disk_read

	; Print message
	mov si, msg_hello
	call puts

	jmp $


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
	jmp $


;
; Disk routines
;

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

	xor dx, dx							; dx = 0
	div word [bdb_sectors_per_track]	; ax = LBA / sectors per track
										; dx = LBA % sectors per track

	inc dx								; dx = LBA % sectors per track + 1 = sector number
	mov cx, dx							; cx = sector number
	xor dx, dx

	div word [bdb_heads]				; ax = (LBA / sectors per track) / heads = cylinder number
										; dx = (LBA / sectors per track) % heads = head number
	mov dh, dl 							; dh = head
	mov ch, al							; ch = cylinder (lower 8 bits)
	shl ah, 6
	or cl, ah							; Put upper 2 bits of cylinder in CL
	
	pop ax
	mov dl, al							; Restore dl
	pop ax
	ret


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
	call lba_to_chs		; Compute CHS
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


msg_hello: 				db "Hello world!", ENDL, 0
msg_read_failed: 		db "Read from disk failed!", ENDL, 0

times 510-($-$$) db 0
dw 0xaa55
