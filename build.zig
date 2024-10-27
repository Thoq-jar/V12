const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const exe = b.addExecutable(.{
        .name = "v12",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = .ReleaseFast,
    });

    exe.linkLibC();
    b.installArtifact(exe);
}
