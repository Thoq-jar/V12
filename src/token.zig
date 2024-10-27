const std = @import("std");

pub const TokenType = enum {
    // Keywords
    For,
    Let,
    Console,
    Log,

    // Symbols
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    Semicolon,
    Equal,
    Less,
    Plus,
    Plus2, // ++
    Dot, // .

    // Literals
    Number,
    String,
    Identifier,

    Eof,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    line: usize,
};

var keywords: std.StringHashMap(TokenType) = undefined;

pub fn initKeywords(allocator: std.mem.Allocator) !void {
    keywords = std.StringHashMap(TokenType).init(allocator);
    try keywords.put("for", .For);
    try keywords.put("let", .Let);
    try keywords.put("console", .Console);
    try keywords.put("log", .Log);
}

pub fn deinitKeywords() void {
    keywords.deinit();
}

pub fn getKeywordType(text: []const u8) ?TokenType {
    return keywords.get(text);
}
