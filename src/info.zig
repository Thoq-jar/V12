const std = @import("std");

pub const VERSION = "0.4.0";

const banner =
    \\██╗   ██╗ ██╗██████╗     ███████╗███╗   ██╗ ██████╗ ██╗███╗   ██╗███████╗
    \\██║   ██║███║╚════██╗    ██╔════╝████╗  ██║██╔════╝ ██║████╗  ██║██╔════╝
    \\██║   ██║╚██║ █████╔╝    █████╗  ██╔██╗ ██║██║  ███╗██║██╔██╗ ██║█████╗  
    \\╚██╗ ██╔╝ ██║██╔═══╝     ██╔══╝  ██║╚██╗██║██║   ██║██║██║╚██╗██║██╔══╝  
    \\ ╚████╔╝  ██║███████╗    ███████╗██║ ╚████║╚██████╔╝██║██║ ╚████║███████╗
    \\  ╚═══╝   ╚═╝╚══════╝    ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝╚══════╝
    \\
;
pub fn printHelp() !void {
    const stdout = std.io.getStdOut().writer();
    const help_text =
        \\V12 - A JavaScript Engine written in Zig
        \\
        \\Usage: v12 [options] <file.js>
        \\
        \\Options:
        \\  -h, --help     Show this help message
        \\  -v, --version  Show version information
        \\  --verbose      Enable verbose output
        \\
        \\Examples:
        \\  v12 script.js
        \\  v12 --verbose script.js
        \\
    ;
    try stdout.writeAll(banner);
    try stdout.writeAll(help_text);
}

pub fn printVersion() !void {
    const stdout = std.io.getStdOut().writer();
    const version_text = std.fmt.comptimePrint(
        \\V12 - A JavaScript Engine written in Zig
        \\Version {s}
        \\
    , .{VERSION});
    try stdout.writeAll(banner);
    try stdout.writeAll(version_text);
}
