// extern 变量是声明zig如何去访问这些变量的,链接器负责找到同名符号
extern var __bss: u8;
extern var __bss_end: u8;
extern var __stack_top: u8;
const std = @import("std");
const printf = @import("common.zig").printf;
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
    while (true) {
        asm volatile ("wfi");
    }
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
