const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const runtime = @import("runtime.zig");
const token = @import("token.zig");
const info = @import("info.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    const stdout = std.io.getStdOut().writer();

    try token.initKeywords(allocator);
    defer token.deinitKeywords();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next();

    var is_file_source = false;
    var filepath: ?[]u8 = null;
    var verbose = false;

    defer if (filepath) |path| allocator.free(path);

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try info.printHelp();
            return;
        } else if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            try info.printVersion();
            return;
        } else if (std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
        } else {
            if (!std.mem.endsWith(u8, arg, ".js")) {
                try stdout.print("Error: File must have a .js extension!\n", .{});
                if (std.mem.endsWith(u8, arg, ".ts")) {
                    try stdout.print("Typescript support is coming at a later time!\n", .{});
                }
                return error.InvalidFileExtension;
            }
            filepath = try allocator.dupe(u8, arg);
        }
    }

    const source = if (filepath) |path| blk: {
        is_file_source = true;
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);

        const bytes_read = try file.readAll(buffer);
        const source = try allocator.dupe(u8, buffer[0..bytes_read]);
        break :blk source;
    } else {
        return error.NoInputFile;
    };
    defer allocator.free(source);

    var lex = lexer.Lexer.init(allocator, source, verbose);
    defer lex.deinit();

    const tokens = try lex.scanTokens();
    var parse = try parser.Parser.init(allocator, tokens, verbose);
    defer parse.deinit();

    const ast = try parse.parse();
    defer ast.deinit();

    var interp = try runtime.Interpret.init(allocator);
    defer interp.deinit();

    try interp.interpret(ast);
}
