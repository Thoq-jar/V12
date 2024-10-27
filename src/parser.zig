const std = @import("std");
const token = @import("token.zig");
const ast = @import("ast.zig");

pub const ParseError = error{
    ParseError,
    OutOfMemory,
} || std.fs.File.WriteError;

pub const Parser = struct {
    allocator: std.mem.Allocator,
    tokens: []const token.Token,
    current: usize,
    stdout: std.fs.File.Writer,
    verbose: bool,

    pub fn init(allocator: std.mem.Allocator, tokens: []const token.Token, verbose: bool) !Parser {
        return Parser{
            .allocator = allocator,
            .tokens = tokens,
            .current = 0,
            .stdout = std.io.getStdOut().writer(),
            .verbose = verbose,
        };
    }

    pub fn deinit(self: *Parser) void {
        _ = self;
    }

    pub fn parse(self: *Parser) !*ast.Node {
        try self.log("Starting parse\n", .{});
        const program = try ast.Node.init(self.allocator, .Program, self.peek());
        errdefer program.deinit();

        while (!self.isAtEnd()) {
            try self.log("Parsing statement at token: {any}\n", .{self.peek()});
            const stmt = try self.statement() orelse break;
            errdefer stmt.deinit();
            try program.addChild(stmt);
        }

        return program;
    }

    fn statement(self: *Parser) ParseError!?*ast.Node {
        try self.log("Current token type: {any}\n", .{self.peek().type});
        if (self.isAtEnd()) return null;

        if (self.match(.For)) {
            return self.forStatement();
        }
        if (self.match(.LeftBrace)) {
            return self.blockStatement();
        }

        const stmt = try self.expressionStatement();
        errdefer stmt.deinit();
        return stmt;
    }

    fn forStatement(self: *Parser) ParseError!*ast.Node {
        try self.log("Parsing for statement\n", .{});
        const for_token = self.previous();
        const node = try ast.Node.init(self.allocator, .ForStatement, for_token);
        errdefer node.deinit();

        _ = try self.consume(.LeftParen, "Expected '(' after 'for'.");

        const initialization = try self.varDeclaration();
        try node.addChild(initialization);

        const condition = try self.expression();
        try node.addChild(condition);
        _ = try self.consume(.Semicolon, "Expected ';' after loop condition.");

        const increment = try self.expression();
        try node.addChild(increment);
        _ = try self.consume(.RightParen, "Expected ')' after for clauses.");

        const body = (try self.statement()) orelse return error.ParseError;
        try node.addChild(body);

        return node;
    }

    fn varDeclaration(self: *Parser) ParseError!*ast.Node {
        try self.log("Parsing var declaration\n", .{});
        const is_const = self.match(.Const);
        if (!is_const) {
            _ = try self.consume(.Let, "Expected 'let' or 'const' keyword.");
        }
        const name = try self.consume(.Identifier, "Expected variable name.");
        _ = try self.consume(.Equal, "Expected '=' after variable name.");
        const initializer = try self.expression();
        errdefer initializer.deinit();
        _ = try self.consume(.Semicolon, "Expected ';' after variable declaration.");

        const node = try ast.Node.init(self.allocator, .VarDeclaration, name);
        errdefer node.deinit();
        try node.addChild(initializer);
        return node;
    }

    fn expression(self: *Parser) ParseError!*ast.Node {
        try self.log("Parsing expression\n", .{});
        return self.addition();
    }

    fn addition(self: *Parser) ParseError!*ast.Node {
        var expr = try self.multiplication();
        errdefer expr.deinit();

        while (self.match(.Plus) or self.match(.Minus)) {
            const operator = self.previous();
            const right = try self.multiplication();
            errdefer right.deinit();

            var new_expr = try ast.Node.init(self.allocator, .BinaryExpression, operator);
            try new_expr.addChild(expr);
            try new_expr.addChild(right);
            expr = new_expr;
        }
        return expr;
    }

    fn multiplication(self: *Parser) ParseError!*ast.Node {
        var expr = try self.comparison();
        errdefer expr.deinit();

        while (self.match(.Star) or self.match(.Slash)) {
            const operator = self.previous();
            const right = try self.comparison();
            errdefer right.deinit();

            var new_expr = try ast.Node.init(self.allocator, .BinaryExpression, operator);
            try new_expr.addChild(expr);
            try new_expr.addChild(right);
            expr = new_expr;
        }
        return expr;
    }

    fn comparison(self: *Parser) ParseError!*ast.Node {
        std.debug.print("Parsing comparison\n", .{});
        var expr = try self.primary();
        errdefer expr.deinit();

        while (self.match(.Less)) {
            const operator = self.previous();
            const right = try self.primary();
            errdefer right.deinit();

            var new_expr = try ast.Node.init(self.allocator, .BinaryExpression, operator);
            try new_expr.addChild(expr);
            try new_expr.addChild(right);
            expr = new_expr;
        }

        return expr;
    }

    fn primary(self: *Parser) ParseError!*ast.Node {
        try self.log("Parsing primary. Current token: {any}\n", .{self.peek()});

        if (self.match(.String)) {
            return ast.Node.init(self.allocator, .StringLiteral, self.previous());
        }
        if (self.match(.Number)) {
            return ast.Node.init(self.allocator, .NumberLiteral, self.previous());
        }
        if (self.match(.Console)) {
            const console = try ast.Node.init(self.allocator, .Identifier, self.previous());
            errdefer console.deinit();

            _ = try self.consume(.Dot, "Expected '.' after 'console'");
            const method = if (self.match(.Log))
                self.previous()
            else if (self.match(.Warn))
                self.previous()
            else if (self.match(.Error))
                self.previous()
            else
                return error.ParseError;

            _ = try self.consume(.LeftParen, "Expected '(' after method name");

            var node = try ast.Node.init(self.allocator, .CallExpression, method);
            errdefer node.deinit();

            try node.addChild(console);
            try node.addChild(try ast.Node.init(self.allocator, .Identifier, method));

            while (!self.check(.RightParen)) {
                const arg = try self.expression();
                errdefer arg.deinit();
                try node.addChild(arg);

                if (!self.check(.RightParen)) {
                    _ = try self.consume(.Comma, "Expected ',' between arguments");
                }
            }

            _ = try self.consume(.RightParen, "Expected ')' after arguments");
            return node;
        }
        if (self.match(.Identifier)) {
            const id = try ast.Node.init(self.allocator, .Identifier, self.previous());
            errdefer id.deinit();

            if (self.match(.Plus2)) {
                const node = try ast.Node.init(self.allocator, .UpdateExpression, self.previous());
                errdefer node.deinit();
                try node.addChild(id);
                return node;
            }
            return id;
        }

        return error.ParseError;
    }

    fn peek(self: Parser) token.Token {
        return self.tokens[self.current];
    }

    fn previous(self: Parser) token.Token {
        return self.tokens[self.current - 1];
    }

    fn match(self: *Parser, token_type: token.TokenType) bool {
        if (self.check(token_type)) {
            self.current += 1;
            return true;
        }
        return false;
    }

    fn check(self: Parser, token_type: token.TokenType) bool {
        if (self.isAtEnd()) return false;
        return self.peek().type == token_type;
    }

    fn consume(self: *Parser, token_type: token.TokenType, message: []const u8) ParseError!token.Token {
        if (self.check(token_type)) {
            self.current += 1;
            return self.previous();
        }
        std.debug.print("Parse error: {s}\n", .{message});
        return error.ParseError;
    }

    fn isAtEnd(self: Parser) bool {
        return self.peek().type == .Eof;
    }

    fn expressionStatement(self: *Parser) ParseError!*ast.Node {
        const expr = try self.expression();
        errdefer expr.deinit();

        if (!self.check(.RightBrace)) {
            _ = try self.consume(.Semicolon, "Expected ';' after expression.");
        }

        return expr;
    }

    fn advance(self: *Parser) token.Token {
        if (!self.isAtEnd()) {
            self.current += 1;
        }
        return self.previous();
    }

    fn blockStatement(self: *Parser) ParseError!*ast.Node {
        const node = try ast.Node.init(self.allocator, .BlockStatement, self.previous());
        errdefer node.deinit();

        while (!self.check(.RightBrace) and !self.isAtEnd()) {
            const stmt = (try self.statement()) orelse return error.ParseError;
            errdefer stmt.deinit();
            try node.addChild(stmt);
        }

        _ = try self.consume(.RightBrace, "Expected '}' after block.");
        return node;
    }

    fn log(self: *Parser, comptime fmt: []const u8, args: anytype) !void {
        if (self.verbose) {
            try self.stdout.print(fmt, args);
        }
    }
};
