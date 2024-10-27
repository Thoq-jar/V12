const std = @import("std");
const token = @import("token.zig");

pub const NodeType = enum {
    Program,
    ForStatement,
    VarDeclaration,
    BinaryExpression,
    CallExpression,
    MemberExpression,
    UpdateExpression,
    BlockStatement,
    Identifier,
    NumberLiteral,
    StringLiteral,
};

pub const Node = struct {
    type: NodeType,
    token: token.Token,
    children: std.ArrayList(*Node),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, node_type: NodeType, tok: token.Token) !*Node {
        const node = try allocator.create(Node);
        errdefer allocator.destroy(node);

        node.* = .{
            .type = node_type,
            .token = tok,
            .children = std.ArrayList(*Node).init(allocator),
            .allocator = allocator,
        };
        return node;
    }

    pub fn deinit(self: *Node) void {
        for (self.children.items) |child| {
            child.deinit();
        }
        self.children.deinit();
        self.allocator.destroy(self);
    }

    pub fn addChild(self: *Node, child: *Node) !void {
        try self.children.append(child);
    }
};
