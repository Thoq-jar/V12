const std = @import("std");
const parser = @import("parser.zig");
const ast = @import("ast.zig");
const lexer = @import("lexer.zig");
const io = @import("io.zig");

const Color = io.Color;

pub const Value = union(enum) {
    number: f128,
    string: []const u8,
    undefined: void,
};

pub const Environment = struct {
    parent: ?*Environment,
    variables: std.StringHashMap(Value),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, parent: ?*Environment) !*Environment {
        const env = try allocator.create(Environment);
        env.* = .{
            .parent = parent,
            .variables = std.StringHashMap(Value).init(allocator),
            .allocator = allocator,
        };
        return env;
    }

    pub fn deinit(self: *Environment) void {
        self.variables.deinit();
        self.allocator.destroy(self);
    }

    pub fn define(self: *Environment, name: []const u8, value: Value) !void {
        try self.variables.put(name, value);
    }

    pub fn get(self: *Environment, name: []const u8) ?Value {
        if (self.variables.get(name)) |value| {
            return value;
        }
        if (self.parent) |parent| {
            return parent.get(name);
        }
        return null;
    }

    pub fn assign(self: *Environment, name: []const u8, value: Value) !void {
        if (self.variables.contains(name)) {
            try self.variables.put(name, value);
            return;
        }
        if (self.parent) |parent| {
            try parent.assign(name, value);
            return;
        }
        return error.UndefinedVariable;
    }
};

pub const InterpreterError = error{
    RuntimeError,
    OutOfMemory,
    UnhandledNodeType,
    UndefinedVariable,
    Overflow,
    InvalidCharacter,
    ParseError,
} || std.fs.File.WriteError;

pub const Interpret = struct {
    allocator: std.mem.Allocator,
    environment: *Environment,

    pub fn init(allocator: std.mem.Allocator) !Interpret {
        io.init();
        const env = try Environment.init(allocator, null);
        return Interpret{
            .allocator = allocator,
            .environment = env,
        };
    }

    pub fn deinit(self: *Interpret) void {
        io.deinit();
        self.environment.deinit();
    }

    pub fn interpret(self: *Interpret, node: *ast.Node) InterpreterError!void {
        try self.visitNode(node);
    }

    fn visitNode(self: *Interpret, node: *ast.Node) InterpreterError!void {
        switch (node.type) {
            .Program => {
                for (node.children.items) |child| {
                    try self.visitNode(child);
                }
            },
            .BlockStatement => {
                for (node.children.items) |child| {
                    try self.visitNode(child);
                }
            },
            .ForStatement => try self.visitForStatement(node),
            .VarDeclaration => try self.visitVarDeclaration(node),
            .CallExpression => try self.visitCallExpression(node),
            .NumberLiteral => {},
            .UpdateExpression => {
                _ = try self.evaluateExpression(node);
            },
            .WhileStatement => try self.visitWhileStatement(node),
            .AssignmentExpression => {
                const identifier = node.children.items[0];
                const value = try self.evaluateExpression(node.children.items[1]);
                try self.environment.assign(identifier.token.lexeme, value);
            },
            else => return error.UnhandledNodeType,
        }
    }

    fn visitForStatement(self: *Interpret, node: *ast.Node) InterpreterError!void {
        const init_node = node.children.items[0];
        try self.visitNode(init_node);

        const condition = node.children.items[1];
        const update = node.children.items[2];
        const body = node.children.items[3];

        while (try self.evaluateCondition(condition)) {
            try self.visitNode(body);
            try self.visitNode(update);
        }
    }

    fn evaluateCondition(self: *Interpret, node: *ast.Node) InterpreterError!bool {
        switch (node.type) {
            .BinaryExpression => {
                const left = try self.evaluateExpression(node.children.items[0]);
                const right = try self.evaluateExpression(node.children.items[1]);

                if (node.token.type == .Less) {
                    return left.number < right.number;
                }
                return false;
            },
            else => return false,
        }
    }

    fn visitVarDeclaration(self: *Interpret, node: *ast.Node) InterpreterError!void {
        const name = node.token.lexeme;
        const value = try self.evaluateExpression(node.children.items[0]);
        try self.environment.define(name, value);
    }

    fn visitCallExpression(self: *Interpret, node: *ast.Node) InterpreterError!void {
        const callee = node.children.items[0];

        if (callee.token.type == .Console) {
            const method = node.children.items[1].token.type;
            const args = node.children.items[2..];

            const color = switch (method) {
                .Log => Color.Reset,
                .Warn => Color.Yellow,
                .Error => Color.Red,
                else => Color.Reset,
            };

            for (args) |arg| {
                const value = try self.evaluateExpression(arg);
                if (value == .number) {
                    try self.printValue(value);
                } else {
                    io.writeText(switch (value) {
                        .string => |s| s,
                        .undefined => "undefined",
                        else => unreachable,
                    }, color);
                    io.writeText(" ", color);
                }
            }
            io.writeText("", .Reset);
            io.writeNewline();
        }
    }

    fn evaluateExpression(self: *Interpret, node: *ast.Node) InterpreterError!Value {
        switch (node.type) {
            .UpdateExpression => {
                const identifier = node.children.items[0];
                const name = identifier.token.lexeme;
                if (self.environment.get(name)) |value| {
                    const new_value = Value{ .number = value.number + 1 };
                    try self.environment.assign(name, new_value);
                    return new_value;
                }
                return error.UndefinedVariable;
            },
            .BinaryExpression => {
                const left = try self.evaluateExpression(node.children.items[0]);
                const right = try self.evaluateExpression(node.children.items[1]);

                switch (node.token.type) {
                    .Plus => return Value{ .number = left.number + right.number },
                    .Minus => return Value{ .number = left.number - right.number },
                    .Star => return Value{ .number = left.number * right.number },
                    .Slash => return Value{ .number = left.number / right.number },
                    .Less => return Value{ .number = if (left.number < right.number) 1 else 0 },
                    else => return Value{ .undefined = {} },
                }
            },
            .NumberLiteral => {
                const num = try std.fmt.parseFloat(f64, node.token.lexeme);
                return Value{ .number = num };
            },
            .StringLiteral => {
                return Value{ .string = node.token.lexeme };
            },
            .Identifier => {
                if (self.environment.get(node.token.lexeme)) |value| {
                    return value;
                }
                return error.UndefinedVariable;
            },
            .AssignmentExpression => {
                const identifier = node.children.items[0];
                const value = try self.evaluateExpression(node.children.items[1]);
                try self.environment.assign(identifier.token.lexeme, value);
                return value;
            },
            else => return Value{ .undefined = {} },
        }
    }

    fn printValue(self: *Interpret, value: Value) InterpreterError!void {
        switch (value) {
            .number => |n| {
                const int_part = @floor(n);
                if (n == int_part) {
                    io.writeNumber(@as(i64, @intFromFloat(n)));
                } else {
                    const formatted = try std.fmt.allocPrint(self.allocator, "{d:.10}", .{n});
                    defer self.allocator.free(formatted);
                    var end = formatted.len - 1;
                    while (end > 0 and formatted[end] == '0') end -= 1;
                    if (formatted[end] == '.') end -= 1;
                    io.writeText(formatted[0 .. end + 1], .Reset);
                }
            },
            .string => |s| io.writeText(s, .Reset),
            .undefined => io.writeText("undefined", .Reset),
        }
        io.writeText(" ", .Reset);
    }

    fn visitWhileStatement(self: *Interpret, node: *ast.Node) InterpreterError!void {
        const condition = node.children.items[0];
        const body = node.children.items[1];

        while (try self.evaluateCondition(condition)) {
            try self.visitNode(body);
        }
    }
};
