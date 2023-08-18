# OS Start - Get it Running
When the computer starts up, the device will search for a bootable disk in order to start the operating system. There are two ways that BIOS (Basic Input/Output System) can do this:

1. Legacy booting
    - BIOS loads the first sector of each bootable device into memory at location `0x7c00`
    - BIOS checks for `0xaa55` signature (magic number) to signify that the disk sector is a **boot sector**
    - If found, transfers execution to the boot sector
2. EFI
    - BIOS looks into special EFI partitions
    - Operating system must be compiled as an EFI program

For simplicity, I will be using the legacy booting method. During the **boot sequence**, execution is transfered to the valid boot sector. The **machine code** (binary) in the boot sector will be executed, since the CPU only understands machine code instructions. As such, it is important that the start of the OS is written as machine code for the CPU to interpret. The easiest way to do this is through **assembly language**, a human-readable programming language that can directly translate to machine code. FOr the purposes of this project, I will be using the **x86** assembly language, since I will be emulating an x86 processor.

Moving onto programming the boot sector, the instructions should be specified to start at address `0x7c00`, since that is where they will be loaded into memory during the **boot sequence**. This can be done with the `org` directive, which specifies the offset for calculating the location of labels and variables.

```assembly
org 0x7c00
```

#### Directive
- Gives a clue to the assembler that will affect how the program gets compiled. Does **not** get translated to machine code!
- Assembler specific - different assemblers might have different directives.
#### Instruction
- Translated to a machine code instruction that the CPU will execute.

Next we need to ensure that the machine code emitted by the **assembler** is in 16-bit code, as any x86 CPU needs to be backwards compatible with the original 8086 CPU. As such, the CPU starts in 16-bit mode, which interprets 16-bit instructions, meaning our boot sector needs to contain 16-bit machine code. This can be done with the `bits` directive.

```assembly
bits 16
```

We can then write a simple OS that runs indefinitely by continuously looping.

```assembly
main:
    hlt

.halt:
    jmp .halt
```

Finally, we need to ensure that this portion of machine code is interpreted as a boot sector. This is done with the `0xaa55` signature as the last two bytes of the sector. The **`db`**, **`dw`**, and **`times`** directives will be useful for this.

**`db`** - Writes given bytes to the binary file
**`dw`** - Writes given words (2 bytes) to the binary file
**`times`** - Repeats given instructions or piece of data a number of times

With *nasm* (x86 assembler) there are two special symbols **`$`** and **`$$`** which are also useful.

**`$`** - The memory offset of the current line
**`$$`** - The memory offset of the beginning of the current section (program in our case)

Using these, we can pad the rest of the sector (510 bytes - program length) with 0s and put the magic number at the end (last 2 bytes).

```assembly
time 510-($-$$) db 0
dw 0xaa55
```

After this, you should end up with a file that looks like this:

```assembly
org 0x7c00
bits 16

main:
    hlt

.halt
    jmp .halt

times 510-($-$$) db 0
dw 0xaa55
```

You can can then compile the program into a "bootable disk" by running `make` in the `start_running` directory. The file can then be started in the *qemu* emulator by using the `make run` command. You should now have a running OS!

[Table of Contents](../README.md)

[Next - Hello World!](../hello_world/README.md)