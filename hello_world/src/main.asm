org 0x7C00
bits 16


%define ENDL 0x0D, 0x0A


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
	lodsb		; Loads next character in al
	or al, al	; Verify if next character is null?
	jz .done

	mov ah, 0x0e	; Call bios interrupt
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
	mov ax, 0	; can't write to ds/es directly
	mov ds, ax
	mov es, ax

	; Setup stack
	mov ss, ax
	mov sp, 0x7C00	; Stack grows downwards from where we are loaded in memory

	; Print message
	mov si, msg_hello
	call puts

	hlt

.halt:
	jmp .halt


msg_hello: db "Hello world!", ENDL, 0

times 510-($-$$) db 0
dw 0xaa55
