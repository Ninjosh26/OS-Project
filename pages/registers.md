# x86 CPU Registers
All processors have registers, which are small pieces of memory that can be written to and read from very fast.

## General Purpose Registers
Can be used for almost any purpose, so they are the primary registers for most assembly programs. These include registers: **A**, **B**, **C**, **D**, **8**, **9**, **10**, **11**, **12**, **13**, **14**, **15**, **BP**, **SI**, **DI**, and **SP**. Some of these are important for certain subroutines, and others have special purposes. **BP** is the base pointer register, **SP** is the stack pointer register. 

All of these registers also have 8-bit, 16-bit, 32-bit, and 64-bit variations. **A-D** 64-bit registers are **RAX-RDX**. The lower 32-bits of the register can be accessed with **EAX-EDX**. The lower 16-bits can be accessed with **AX-DX**, and these registers are also split into the upper 8-bits and lower 8-bits with **AH-DH** and **AL-DL** respectively. The other registers work similarly, although with different names and they also don't have the upper 8-bits of the 16-bit register.

## Status Registers
There are 2 special registers for describing program behavior, the **IP** and **FLAGS** registers. The **IP** register keeps track of the program counter, which is the address of the current instruction being run on the CPU. As such, there are only 16-bit, 32-bit, and 64-bit variations of this register, as each one corresponds to an address space size. The **FLAGS** register keeps track of various program flags, namely the results of comparisons.

## Segment Registers
The **CS**, **SS**, **DS**, **ES**, **FS**, and **GS** registers keep track of the currently active memory segments. These registers are all 16-bits.

#### Memory Segmentation
In the x86 architecture, memory is addressed using a segmentation scheme, with 16-bit segment and offset values. Segments are separated by 16 bytes, and each segment is 64kB long. This means that the address can be calculated with `address = segment * 16 + offset`. An example of this would be the segmentation, `0x00c0:0x7000`. This would correspond to the memory address `0x7c00`.

**CS** - Currently running code segment
**DS** - Data segment
**SS** - Stack segment
**ES, FS, GS** - Extra (data) segments

## Referencing a Memory Location
At times it is useful to reference data at a specific location. The `[]` symbols allow for accessing data starting at the specified offset.

```assembly
var: dw 100

    mov ax, var     ; Copy offset to ax
    mov ax, [var]   ; Copy memory contents
```

In the above example, a **word** (16-bits) is defined with the value 100 and is given the label `var`. `mov` is an x86 instruction that copies data from a source (register, memory reference, constant) to a destination (register, memory reference). The left value is the destination, and the right value is the source. The variable label corresponds to the offset of the declared word, so moving it results in storing the offset in `ax`. By putting it in `[]`s, the data at the offset is instead moved into the register. Because `ax` is a 16-bit register, 16-bits starting from the `var` label's offset will be copied into the register. This is especially useful for interacting with arrays.

```assembly
array: dw 100, 200, 300

    mov bx, array       ; Copy offset to ax
    mov si, 2 * 2       ; array[2], words are 2 bytes wide
    mov ax, [bx + si]   ; Copy memory contents
```

In this example, a continuous segment of 3 words are allocated, with the start of it given the label `array`. In order to access the value at index 2 of the array, we would need to move 4 bytes from the start of `array`, since each word is 2 bytes. This can be done by first moving the offset of the start of the array into a base register (`bx`), then storing the 4 byte offset into an index register (`si`). `array[2]` can then be accessed by accessing the 16-bits (word) at `bx + si`.

[Table of Contents](../README.md)

[Hello World](../hello_world/README.md)