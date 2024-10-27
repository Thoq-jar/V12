const std = @import("std");
const parser = @import("parser.zig");
const ast = @import("ast.zig");

pub const Value = union(enum) {
    number: i64,
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
} || std.fs.File.WriteError;

pub const Interpreter = struct {
    allocator: std.mem.Allocator,
    environment: *Environment,

    pub fn init(allocator: std.mem.Allocator) !Interpreter {
        const env = try Environment.init(allocator, null);
        return .{
            .allocator = allocator,
            .environment = env,
        };
    }

    pub fn deinit(self: *Interpreter) void {
        self.environment.deinit();
    }

    pub fn interpret(self: *Interpreter, node: *ast.Node) InterpreterError!void {
        try self.visitNode(node);
    }

    fn visitNode(self: *Interpreter, node: *ast.Node) InterpreterError!void {
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
            else => return error.UnhandledNodeType,
        }
    }

    fn visitForStatement(self: *Interpreter, node: *ast.Node) InterpreterError!void {
        const initialization = node.children.items[0];
        const condition = node.children.items[1];
        const update = node.children.items[2];
        const body = node.children.items[3];

        try self.visitNode(initialization);

        while (try self.evaluateCondition(condition)) {
            try self.visitNode(body);
            try self.visitNode(update);
        }
    }

    fn evaluateCondition(self: *Interpreter, node: *ast.Node) InterpreterError!bool {
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

    fn visitVarDeclaration(self: *Interpreter, node: *ast.Node) InterpreterError!void {
        const name = node.token.lexeme;
        const value = try self.evaluateExpression(node.children.items[0]);
        try self.environment.define(name, value);
    }

    fn visitCallExpression(self: *Interpreter, node: *ast.Node) InterpreterError!void {
        const callee = node.children.items[0];
        if (callee.token.type == .Console) {
            const args = node.children.items[1..];
            for (args) |arg| {
                const value = try self.evaluateExpression(arg);
                try self.printValue(value);
            }
            try std.io.getStdOut().writer().writeByte('\n');
        }
    }

    fn evaluateExpression(self: *Interpreter, node: *ast.Node) InterpreterError!Value {
        switch (node.type) {
            .NumberLiteral => {
                const num = try std.fmt.parseInt(i64, node.token.lexeme, 10);
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
            .BinaryExpression => {
                const left = try self.evaluateExpression(node.children.items[0]);
                const right = try self.evaluateExpression(node.children.items[1]);
                if (node.token.type == .Less) {
                    return Value{ .number = if (left.number < right.number) 1 else 0 };
                }
                return Value{ .number = left.number };
            },
            .UpdateExpression => {
                const id = node.children.items[0];
                if (self.environment.get(id.token.lexeme)) |value| {
                    var new_value = value;
                    new_value.number += 1;
                    try self.environment.define(id.token.lexeme, new_value);
                    return new_value;
                }
                return error.UndefinedVariable;
            },
            else => return Value{ .undefined = {} },
        }
    }

    fn printValue(self: *Interpreter, value: Value) InterpreterError!void {
        _ = self;
        switch (value) {
            .number => |n| try std.io.getStdOut().writer().print("{d}", .{n}),
            .string => |s| try std.io.getStdOut().writer().writeAll(s),
            .undefined => try std.io.getStdOut().writer().writeAll("undefined"),
        }
    }
};
