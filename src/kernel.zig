// extern 变量是声明zig如何去访问这些变量的,链接器负责找到同名符号
extern var __bss: u8;
extern var __bss_end: u8;
extern var __stack_top: u8;

const std = @import("std");
const printf = @import("common.zig").printf;

// 系统panic函数编写
pub const panic = std.debug.FullPanic(panicHandler);
fn panicHandler(message: []const u8, _: ?usize) noreturn {
    const src = @src();
    printf("Panic!{s}, view panic code at ({s}:{d})\n", .{ message, src.file, src.line });
    while (true) {
        // asm volatile ("wfi");
        // 切换到m级的sbicall会有性能开销(异常处理,特权级切换)
    }
}

// sbi-api implement

// 首先得考虑下如何实现sbi规范,之前看rcore的时候没注意他是调用了rustsbi的crates吃大亏了
const value = union {
    signed_value: i32,
    unsigned_value: u32,
};
const sbriet = struct {
    err_code: u32,
    result: value,
};

fn sbi_call(
    arg0: u32,
    arg1: u32,
    arg2: u32,
    arg3: u32,
    arg4: u32,
    arg5: u32,
    fid: u32,
    eid: u32,
) sbriet {
    var out_a0: u32 = undefined;
    var out_a1: u32 = undefined;
    asm volatile ("ecall"
        : [ret0] "={a0}" (out_a0),
          [ret1] "={a1}" (out_a1),
        : [in0] "0" (arg0),
          [in1] "1" (arg1),
          [in2] "{a2}" (arg2),
          [in3] "{a3}" (arg3),
          [in4] "{a4}" (arg4),
          [in5] "{a5}" (arg5),
          [fid] "{a6}" (fid),
          [eid] "{a7}" (eid),
        : .{ .memory = true });
    return .{
        .err_code = out_a0,
        .result = .{ .unsigned_value = out_a1 },
    };
}

// 实现putchar syscall 用来写hello world

pub fn putchar(ch: u8) void {
    // u8 会自动补全成u32
    _ = sbi_call(ch, 0, 0, 0, 0, 0, 0, 1);
}

// 内核初始化

// 给内核分配初始内存空间
// fn memset(buf: [*]u8, byte: u8, n: usize) [*]u8 {
//     for (buf[0..n]) |*p| {
//         p.* = byte;
//     }
//     return buf;
// }

export fn kernel_main() void {
    // intFromPtr 将地址转换为整数
    const len = @intFromPtr(&__bss_end) - @intFromPtr(&__bss);
    // 初始化.bss段
    const bss: [*]u8 = @ptrCast(&__bss);
    _ = @memset(bss[0..len], 0);

    // helloworld 来
    printf("{s}\n", .{"Hello,world!"});
    writeCsr("stvec", @intFromPtr(&kernel_entry));
    // 伪指令
    // 解析成 csrrw x0 cycle, x0, cycle是只读寄存器,会触发非法指令异常
    asm volatile ("unimp");
}

// 用export 让zig把boot()写进目标文件的符号表
// naked告诉编译器不要在函数体前后生成不必要的代码
// 把boot直接放到0x80200000
export fn boot() linksection(".text.boot") callconv(.naked) noreturn {
    asm volatile (
        \\ mv sp, %[stack_top]
        \\ j kernel_main
        :
        : [stack_top] "r" (&__stack_top),
    );
}

// 4位对齐用来约束指令入口地址
fn kernel_entry() align(4) callconv(.naked) void {
    asm volatile (
    // sscratch 寄存器用来当临时存储,用来保存异常发生时的堆栈指针
        \\ csrw sscratch, sp 
        \\ addi sp, sp, -4 * 31    
        \\ sw ra, 4 * 0 (sp) 
        \\ sw gp, 4 * 1 (sp) 
        \\ sw tp, 4 * 2 (sp) 
        \\ sw t0, 4 * 3 (sp) 
        \\ sw t1, 4 * 4 (sp) 
        \\ sw t2, 4 * 5 (sp) 
        \\ sw t3, 4 * 6 (sp) 
        \\ sw t4, 4 * 7 (sp) 
        \\ sw t5, 4 * 8 (sp) 
        \\ sw t6, 4 * 9 (sp) 
        \\ sw a0, 4 * 10 (sp) 
        \\ sw a1, 4 * 11 (sp) 
        \\ sw a2, 4 * 12 (sp) 
        \\ sw a3, 4 * 13 (sp) 
        \\ sw a4, 4 * 14 (sp) 
        \\ sw a5, 4 * 15 (sp) 
        \\ sw a6, 4 * 16 (sp) 
        \\ sw a7, 4 * 17 (sp) 
        \\ sw s0 ,4 * 18 (sp) 
        \\ sw s1 ,4 * 19 (sp) 
        \\ sw s2 ,4 * 20 (sp) 
        \\ sw s3 ,4 * 21 (sp) 
        \\ sw s4 ,4 * 22 (sp) 
        \\ sw s5 ,4 * 23 (sp) 
        \\ sw s6 ,4 * 24 (sp) 
        \\ sw s7 ,4 * 25 (sp) 
        \\ sw s8 ,4 * 26 (sp) 
        \\ sw s9 ,4 * 27 (sp) 
        \\ sw s10 ,4 * 28 (sp) 
        \\ sw s11 ,4 * 29 (sp) 
        \\ csrr a0, sscratch
        \\ sw a0, 4 *30(sp)
        \\ mv a0, sp
        \\ call handle_trap
        // 如果handle trap返回,则将之前的上下文恢复(lw,load words)到寄存器中
        \\ lw ra, 4 * 0 (sp) 
        \\ lw gp, 4 * 1 (sp) 
        \\ lw tp, 4 * 2 (sp) 
        \\ lw t0, 4 * 3 (sp) 
        \\ lw t1, 4 * 4 (sp) 
        \\ lw t2, 4 * 5 (sp) 
        \\ lw t3, 4 * 6 (sp) 
        \\ lw t4, 4 * 7 (sp) 
        \\ lw t5, 4 * 8 (sp) 
        \\ lw t6, 4 * 9 (sp) 
        \\ lw a0, 4 * 10 (sp) 
        \\ lw a1, 4 * 11 (sp) 
        \\ lw a2, 4 * 12 (sp) 
        \\ lw a3, 4 * 13 (sp) 
        \\ lw a4, 4 * 14 (sp) 
        \\ lw a5, 4 * 15 (sp) 
        \\ lw a6, 4 * 16 (sp) 
        \\ lw a7, 4 * 17 (sp) 
        \\ lw s0 ,4 * 18 (sp) 
        \\ lw s1 ,4 * 19 (sp) 
        \\ lw s2 ,4 * 20 (sp) 
        \\ lw s3 ,4 * 21 (sp) 
        \\ lw s4 ,4 * 22 (sp) 
        \\ lw s5 ,4 * 23 (sp) 
        \\ lw s6 ,4 * 24 (sp) 
        \\ lw s7 ,4 * 25 (sp) 
        \\ lw s8 ,4 * 26 (sp) 
        \\ lw s9 ,4 * 27 (sp) 
        \\ lw s10 ,4 * 28 (sp) 
        \\ lw s11 ,4 * 29 (sp)        
        \\ lw sp ,4 * 30 (sp)        
        \\ sret
    );
}

// 用packedstruct让保存的寄存器上下文保存在一块连续的内存里
// packed在这里zig会把这个结构体当作 32*31 = u992的超大整数去进行分配
// 按照这样对齐的结果应该是8位对齐
// 这里用extern struct 直接要求编译器按rv32平台cabi的标准来进行对齐
const trap_frame = extern struct {
    ra: u32,
    gp: u32,
    tp: u32,
    t0: u32,
    t1: u32,
    t2: u32,
    t3: u32,
    t4: u32,
    t5: u32,
    t6: u32,
    a0: u32,
    a1: u32,
    a2: u32,
    a3: u32,
    a4: u32,
    a5: u32,
    a6: u32,
    a7: u32,
    s0: u32,
    s1: u32,
    s2: u32,
    s3: u32,
    s4: u32,
    s5: u32,
    s6: u32,
    s7: u32,
    s8: u32,
    s9: u32,
    s10: u32,
    s11: u32,
    sp: u32,
};

fn readCsr(comptime reg: []const u8) u32 {
    return asm volatile ("csrr %[out], " ++ reg
        : [out] "=r" (-> u32),
    );
}

fn writeCsr(comptime reg: []const u8, reg_value: u32) void {
    asm volatile ("csrw " ++ reg ++ ", %[in]"
        :
        : [in] "r" (reg_value),
    );
}

export fn handle_trap(f: *trap_frame) void {
    _ = f;
    const scause = readCsr("scause");
    const stval = readCsr("stval");
    const user_pc = readCsr("sepc");
    std.debug.panic(" unexpected trap, return scause={x}, stval={x}, user_pc={x}\n", .{
        scause,
        stval,
        user_pc,
    });
}
