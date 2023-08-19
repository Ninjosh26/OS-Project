# Hello World!
The next step of our OS is to print to the screen. We will start with the popular "Hello World!" As part of this goal, it is important to know how to use registers and address memory segments. I have a detailed guide on these topics [here](../pages/registers.md).

The first thing we need to do in order to interact with data is to first set up the data segments. Since the `ds`, `es`, and `ss` registers can't be written to with constants, we first need to write to a general purpose register (`ax`), then to the registers. We will initialize the data segments to 0 in order to start addressing data from the start of memory.

```assembly
main:
    ; Set up data segments
    mov ax, 0       ; Can't write to ds/es directly
    mov ds, ax
    mov es, ax
```

Next, we need to set up the stack, a FIFO (First-In, First-Out) structure used for storing and removing data. This will be necessary for preserving the values of registers, since using them requires overwritting previous data. It is also necessary for function calls, as return addresses are stored on the stack. To set this up, we need to initialize the stack segment and the stack pointer, which stores the address of the "top" of the stack. In reality, the stack grows downwards, meaning that adding to the stack decreases the stack pointer, and removing from the stack increases the stack pointer. Data can be added to the top of the stack with the `push` instruction, and data can be removed from the top of the stack with the `pop` instruction. Since the stack grows downwards, it is important to place the start of it somewhere before our operating system so that it never grows to overwrite our program. We can do this by starting the stack at the start of our operating system (`0x7c00`), as it will only grow downwards.

```assembly
main:
    ...
    ; Set up stack
    mov ss, ax
    mov sp, 0x7c00      ; Stack grows downwards from where we are loaded in memory
```

Now that we have these set up, we can write a function to print a string to the screen. We can do this by defining a function `puts` that prints the screen at location `ds:si`. Since we will need to continuously go through each character of the string, we will need to increase `si`. `ax` will also be necessary for printing the character, so that register will be used as well. Since we are using these registers, we need to save their values on the stack on the start to ensure that their state can be returned at the end.

```assembly
;
; Prints a string to the screen
; Params:
;   - ds:si points to string
;
puts:
    ; Save registers we will modify
    push si
    push ax
```

We then need to loop through each character and run the print character subroutine for each one. The print character subroutine requires that the character be stored in `al`. This can be done with lodsb, which automatically copies the byte from `ds:si` into `al`, then increments `si` by 1 byte. This works because each character is a byte long. Next, we need to check if the next character is null, since strings typically end with a null terminator to signify the end of the string. This tells us when to stop printing. We can do this by calling the `or` instruction between `al` and itself, since it will only evaluate to false if `al` is 0 (null terminator). After calling this instruction, the zero flag will be set. We can conditionally jump if the zero flag is set using the `jz` instruction. We can use this to exit the loop if the null terminator is reached. If we did not jump, that means the character was non-null and should be printed. We can then continue the loop in that case. When exiting the loop, the states of used registers should be return using the `pop` instruction.

```assembly
puts:
    ...
.loop:
    lodsb           ; Loads next character into al
    or al, al       ; Check if next character is null (\0)
    jz .done

    ; INSERT LOGIC FOR PRINTING CHARACTER

    jmp .loop       ; If not null, continue loop

.done:
    pop ax
    pop si
    ret
```

Now, how do we print a character to the screen? Luckily, BIOS handles this for you and provides an interrupt for this. An interrupt will cause the processor to stop what it's doing, and will run a handler based on the interrupt. One such interrupt will print the character stored in `al`. We will use interrupt `10h`, which is in charge of video interactions. In particular, we need to set `ah` to `0eh`, which signifies for teletype output. `bh` is for storing the page number (text modes), and `bl` should be the foreground pixel color (graphics modes). The cursor will advance after each write, and there are special character values which are trated as control codes.

```assembly
.loop:
    ...
    mov ah, 0x0e        ; Set to teletype output
    mov bh, 0           ; Set the page number to 0
    int 0x10            ; Call BIOS interrupt 0x10

.done:
    ...
```

Lastly, we need to declare the string we want to print in memory. We can then store the starting offset of the message in `si`, then call the `puts` function we wrote. Since we will also want to go to the next line after printing, we need to add the carriage character to the end of the string. We can create an easy shorthand for this with a macro (we'll call it ENDL).

```assembly
org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A

main:
    ...
    ; Print message
    mov si, msg_hello
    call puts

    hlt

.halt:
    ...

msg_hello: db "Hello World!", ENDL, 0    
```

After running the machine code for this program, the result should be printing "Hello, World!" to the screen. The completed program can be seen [here](./src/main.asm), assembled with `make`, and run with `make run`.

[Table of Contents](../README.md)

[Previous - OS Start](../start_running/README.md)

[Next - Reading from a Disk](../disk_reading/README.md)