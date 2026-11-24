#!/bin/bash

set -xue

QEMU=qemu-system-riscv32
ZIG=~/.zvm/bin/zig

$ZIG build 
$QEMU -machine virt -bios default -nographic -serial mon:stdio --no-reboot -kernel zig-out/bin/304os.elf
