const std = @import("std");
const Writer = std.Io.Writer;
const fmt = std.fmt;
const putchar = @import("kernel.zig").putchar;
// 用zig的任意类型来接收元组

fn writeBytes(bytes: []const u8) void {
    for (bytes) |byte| {
        putchar(byte);
    }
}

fn drain(_: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
    // drain的逻辑如下:
    // writer会对buffer内的数据自行处理,超出buffer的部分传输给drain处理,drain可自行实现
    // data 是字节切片的切片: 外层是片段列表,内层是片段长度
    const last = data.len - 1;
    for (data[0..last]) |bytes| writeBytes(bytes);
    // splat标志末尾字段需要重复几次
    // 这个是标准库写入辅助函数传下来的
    for (0..splat) |_| writeBytes(data[last]);
    // 最后返回末尾字段重复了几次
    return Writer.countSplat(data, splat);
}

// 初始化一个Writer.Vtable字段用来存储设置好的drain行为
const console_vtable = Writer.VTable{ .drain = drain };

pub fn printf(comptime format: []const u8, args: anytype) void {
    // 在数据传入的时候,程序会先检查容量,然后再决定是写进buffer还是直接用drain处理
    // 用buffer的话简单来说就可以把drain传入的data聚合起来一块输出
    // 用drain的话就得多调几次for循环了
    var writer: Writer = .{
        .vtable = &console_vtable,
        //
        // 空buffer直接全部交给drain处理
        .buffer = &.{},
    };
    writer.print(format, args) catch {};
}

