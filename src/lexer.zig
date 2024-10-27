const std = @import("std");
const token = @import("token.zig");

pub const Lexer = struct {
    source: []const u8,
    tokens: std.ArrayList(token.Token),
    start: usize = 0,
    current: usize = 0,
    line: usize = 1,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Lexer {
        return .{
            .source = source,
            .tokens = std.ArrayList(token.Token).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Lexer) void {
        self.tokens.deinit();
    }

    pub fn scanTokens(self: *Lexer) ![]const token.Token {
        while (!self.isAtEnd()) {
            self.start = self.current;
            try self.scanToken();
        }

        try self.tokens.append(.{
            .type = .Eof,
            .lexeme = "",
            .line = self.line,
        });

        return self.tokens.items;
    }

    fn scanToken(self: *Lexer) !void {
        const c = self.advance();
        switch (c) {
            '"' => try self.string(),
            '(' => try self.addToken(.LeftParen),
            ')' => try self.addToken(.RightParen),
            '{' => try self.addToken(.LeftBrace),
            '}' => try self.addToken(.RightBrace),
            ';' => try self.addToken(.Semicolon),
            '<' => try self.addToken(.Less),
            '.' => try self.addToken(.Dot),
            '+' => {
                if (self.peek() == '+') {
                    _ = self.advance();
                    try self.addToken(.Plus2);
                } else {
                    try self.addToken(.Plus);
                }
            },
            '=' => try self.addToken(.Equal),
            ' ', '\r', '\t' => {}, // Ignore whitespace
            '\n' => self.line += 1,
            else => {
                if (isDigit(c)) {
                    try self.number();
                } else if (isAlpha(c)) {
                    try self.identifier();
                } else {
                    std.debug.print("Unexpected character at line {}: {c}\n", .{ self.line, c });
                }
            },
        }
    }

    fn string(self: *Lexer) !void {
        while (self.peek() != '"' and !self.isAtEnd()) {
            if (self.peek() == '\n') self.line += 1;
            _ = self.advance();
        }

        if (self.isAtEnd()) {
            std.debug.print("Unterminated string at line {}\n", .{self.line});
            return;
        }

        _ = self.advance(); // Consume closing "
        try self.addToken(.String);
    }

    fn isAtEnd(self: Lexer) bool {
        return self.current >= self.source.len;
    }

    fn advance(self: *Lexer) u8 {
        self.current += 1;
        return self.source[self.current - 1];
    }

    fn addToken(self: *Lexer, token_type: token.TokenType) !void {
        const lexeme = self.source[self.start..self.current];
        try self.tokens.append(.{
            .type = token_type,
            .lexeme = lexeme,
            .line = self.line,
        });
    }

    fn number(self: *Lexer) !void {
        while (isDigit(self.peek())) {
            _ = self.advance();
        }
        try self.addToken(.Number);
    }

    fn identifier(self: *Lexer) !void {
        while (isAlphaNumeric(self.peek())) {
            _ = self.advance();
        }
        const text = self.source[self.start..self.current];
        const token_type = token.getKeywordType(text) orelse .Identifier;
        try self.addToken(token_type);
    }

    fn peek(self: Lexer) u8 {
        if (self.isAtEnd()) return 0;
        return self.source[self.current];
    }
};

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isAlpha(c: u8) bool {
    return (c >= 'a' and c <= 'z') or
        (c >= 'A' and c <= 'Z') or
        c == '_';
}

fn isAlphaNumeric(c: u8) bool {
    return isAlpha(c) or isDigit(c);
}
