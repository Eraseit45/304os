const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv32,
        .os_tag = .freestanding,
        .abi = .none,
    });
    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "304os.elf",
        //启用连接器
        .use_lld = true,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/kernel.zig"),
            .target = target,
            .optimize = optimize,
            // 细化调试输出
            .strip = false,
        }),
    });

    kernel.setLinkerScript(b.path("src/linker.ld"));

    kernel.entry = .{ .symbol_name = "boot" };

    b.installArtifact(kernel);
}
