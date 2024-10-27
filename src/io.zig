const std = @import("std");

pub const Color = enum {
    Reset,
    Yellow,
    Red,
};

const stdout = std.io.getStdOut().writer();

pub fn writeText(text: []const u8, color: Color) void {
    const color_str = switch (color) {
        .Reset => "\x1b[0m",
        .Yellow => "\x1b[33m",
        .Red => "\x1b[31m",
    };

    stdout.writeAll(color_str) catch return;
    stdout.writeAll(text) catch return;
}

pub fn writeNumber(n: i64) void {
    stdout.writeAll("\x1b[33m") catch return;
    stdout.print("{d}", .{n}) catch return;
    stdout.writeAll("\x1b[0m") catch return;
}

pub fn writeNewline() void {
    stdout.writeByte('\n') catch return;
}

pub fn init() void {}
pub fn deinit() void {}
