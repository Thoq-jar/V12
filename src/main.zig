const std = @import("std");
const lexer = @import("lexer.zig");
const parser = @import("parser.zig");
const interpreter = @import("interpreter.zig");
const token = @import("token.zig");

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
        if (std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
        } else {
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
        break :blk try allocator.dupe(u8, buffer[0..bytes_read]);
    } else blk: {
        try stdout.print("No file provided, using default source\n", .{});
        break :blk "";
    };
    defer if (is_file_source) allocator.free(source);

    var lex = lexer.Lexer.init(allocator, source);
    defer lex.deinit();

    const tokens = try lex.scanTokens();
    var parse = try parser.Parser.init(allocator, tokens, verbose);
    defer parse.deinit();

    const ast = try parse.parse();
    defer ast.deinit();

    var interp = try interpreter.Interpreter.init(allocator);
    defer interp.deinit();

    try interp.interpret(ast);
}
