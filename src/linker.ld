ENTRY(boot)
BASE_ADDRESS = 0x80200000;

SECTIONS
{
  . = BASE_ADDRESS;

  .text :{
    KEEP(*(.text.boot));
    *(.text .text.*);
  }

  .rodata : ALIGN(4) {
    *(.rodata .rodata.*);
  }

  .data : ALIGN(4) {
    __bss = .;
    *(.bss .bss.* .sbss .sbss.*);
    __bss_end = .;
  }

  . = ALIGN(4);
  . += 128 *1024; /* 128KB */
  __stack_top = .;

  /*4KB = 0x1000*/
  /*保证他跟4kb边界对齐*/
  . = ALIGN(4096);
  __free_ram = .;
  . += 64 * 1024 *1024; /* 64MB */
  __free_ram_end = .;
}

