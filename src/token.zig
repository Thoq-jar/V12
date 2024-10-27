const std = @import("std");

pub const TokenType = enum {
    // Keywords
    For,
    Let,
    Const,
    Console,
    Log,
    Warn,
    Error,
    Eval,

    // Symbols
    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    Semicolon,
    Equal,
    Less,
    Plus,
    Minus,
    Star,
    Slash,
    Plus2, // ++
    Dot, // .

    // Literals
    Number,
    String,
    Identifier,

    Eof,
    Comma,
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
    try keywords.put("const", .Const);
    try keywords.put("console", .Console);
    try keywords.put("log", .Log);
    try keywords.put("warn", .Warn);
    try keywords.put("error", .Error);
    try keywords.put("eval", .Eval);
}

pub fn deinitKeywords() void {
    keywords.deinit();
}

pub fn getKeywordType(text: []const u8) ?TokenType {
    return keywords.get(text);
}
