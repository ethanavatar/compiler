const std = @import("std");
const root = @import("root.zig");
const StaticIntegralMap = root.StaticIntegralMap;

const CharacterClass = enum(u8) {
    Eof,
    Character,

    Digit, Letter,
    Whitespace, NewLine,

    ForwardSlash,
};

const State = enum(u8) {
    Illegal,
    Start,
    Eof,

    Character,

    InIdentifier,
    EndIdentifier,

    InInteger,
    EndInteger,

    FoundForwardSlash,
    EndForwardSlash,
    InLineComment,
    EndLineComment,
};

const character_class_map = StaticIntegralMap(u8, CharacterClass).init(.Character, &.{
    .{ .pattern = .{ .basic =  0 }, .result = .Eof },

    .{ .pattern = .{ .range = .{ .start = '0', .end = '9' } }, .result = .Digit  },
    .{ .pattern = .{ .range = .{ .start = 'a', .end = 'z' } }, .result = .Letter },
    .{ .pattern = .{ .range = .{ .start = 'A', .end = 'Z' } }, .result = .Letter },
    .{ .pattern = .{ .basic = '_' }, .result = .Letter },

    .{ .pattern = .{ .basic = ' ' }, .result = .Whitespace },
    .{ .pattern = .{ .range = .{ .start = '\t', .end = '\r' } }, .result = .Whitespace },
    .{ .pattern = .{ .basic = '\n' }, .result = .NewLine }, // Overwrite the above
    
    .{ .pattern = .{ .basic = '/' }, .result = .ForwardSlash },
});

const CharacterClassToState = StaticIntegralMap(CharacterClass, State);
const default_transition = CharacterClassToState.init(State.Illegal, &.{});
const transition_map = StaticIntegralMap(State, CharacterClassToState).init(default_transition, &.{

    .{ .pattern = .{ .basic = .Start }, .result = CharacterClassToState.init(.Illegal, &.{
        .{ .pattern = .{ .basic = .Eof       }, .result = .Eof       },
        .{ .pattern = .{ .basic = .Character }, .result = .Character },

        // Transition back to start to skip a character, not counting it towards the token
        .{ .pattern = .{ .basic = .Whitespace }, .result = .Start },
        .{ .pattern = .{ .basic = .NewLine    }, .result = .Start },

        .{ .pattern = .{ .basic = .Letter }, .result = .InIdentifier },
        .{ .pattern = .{ .basic = .Digit  }, .result = .InInteger    },

        .{ .pattern = .{ .basic = .ForwardSlash }, .result = .FoundForwardSlash },
    }) },

    .{ .pattern = .{ .basic = .FoundForwardSlash }, .result = CharacterClassToState.init(.EndForwardSlash, &.{
        .{ .pattern = .{ .basic = .ForwardSlash }, .result = .InLineComment },
    }) },

    .{ .pattern = .{ .basic = .InLineComment }, .result = CharacterClassToState.init(.InLineComment, &.{
        .{ .pattern = .{ .basic = .NewLine }, .result = .EndLineComment },
    }) },

    .{ .pattern = .{ .basic = .InIdentifier }, .result = CharacterClassToState.init(.EndIdentifier, &.{
        .{ .pattern = .{ .basic = .Letter }, .result = .InIdentifier },
        .{ .pattern = .{ .basic = .Digit  }, .result = .InIdentifier },
    }) },

    .{ .pattern = .{ .basic = .InInteger }, .result = CharacterClassToState.init(.EndInteger, &.{
        .{ .pattern = .{ .basic = .Digit  }, .result = .InInteger },
    }) },

});

const Advance = struct {
    const T = i8;
    pub const zero: @This() = .{ .cursor = 0, .token = 0 };
    pub const one:  @This() = .{ .cursor = 0, .token = 1 };
    pub const skip: @This() = .{ .cursor = 1, .token = 0 };
    cursor: T, token: T,
};

const state_advance_map = StaticIntegralMap(State, Advance).init(.one, &.{
    .{ .pattern = .{ .basic =  .Start          }, .result = .skip },
    .{ .pattern = .{ .basic =  .Eof            }, .result = .zero },

    .{ .pattern = .{ .basic =  .EndIdentifier   }, .result = .zero },
    .{ .pattern = .{ .basic =  .EndInteger      }, .result = .zero },
    .{ .pattern = .{ .basic =  .EndForwardSlash }, .result = .zero },
    .{ .pattern = .{ .basic =  .EndLineComment  }, .result = .zero },
});

const final_states_map = StaticIntegralMap(State, bool).init(false, &.{
    .{ .pattern = .{ .basic =  .Eof            }, .result = true },
    .{ .pattern = .{ .basic =  .Illegal        }, .result = true },
    .{ .pattern = .{ .basic =  .EndIdentifier  }, .result = true },
    .{ .pattern = .{ .basic =  .EndInteger     }, .result = true },
    .{ .pattern = .{ .basic =  .EndLineComment }, .result = true },
    .{ .pattern = .{ .basic =  .Character      }, .result = true },
});

const TokenKind = union(enum) {
    illegal: void,
    identifier: void,
    integer: u32,

    keyword_pub: void,
    keyword_fn: void,

    type_void: void,
    type_i32: void,

    character: u8,
    comment: void,
};

// TODO: replace this with perfect hashing,
// because this does a linear search on every lookup
const keywords_map = std.StaticStringMap(TokenKind).initComptime(&.{
    .{ "pub",  .keyword_pub },
    .{ "fn",   .keyword_fn  },

    .{ "void", .type_void },
    .{ "i32",  .type_i32  },
});

const Tokenizer = struct {
    const Self = @This();

    source: [:0]const u8,
    offset: usize,

    pub fn init(source: [:0]const u8) Self {
        return .{ .source = source, .offset = 0 };
    }

    pub fn next(self: *Self) !?struct { []const u8, TokenKind } {
        if (self.offset >= self.source.len) return null;

        var state: State = .Start;
        var token_length: usize = 0;

        while (!final_states_map.get(state)) {
            const c = self.source[self.offset + token_length];
            const class = character_class_map.get(c);
            state = transition_map.get(state).get(class);

            const advance = state_advance_map.get(state);
            token_length += @intCast(advance.token);
            self.offset  += @intCast(advance.cursor);
        }

        const token = self.source[self.offset..(self.offset + token_length)];
        self.offset += token_length;

        const kind: TokenKind = switch (state) {
            .Illegal       => .illegal,
            .EndIdentifier => keywords_map.get(token) orelse .identifier,
            .EndInteger    => .{ .integer = try std.fmt.parseInt(u32, token, 10) },
            .Character     => .{ .character = token[0] },
            .EndLineComment => .comment,
            else => {
                std.debug.print("unhandled: {any}\n", .{ state });
                unreachable;
            },
        };

        return .{ token, kind };
    }
};

pub fn main() !void {
    const source = 
        \\pub fn add(a: i32, b: i32) i32 {
        \\    c = 42; // Unused
        \\    return a + b;
        \\}
    ;

    var iter = Tokenizer.init(source);
    while (try iter.next()) |p| {
        const token, const kind = p;
        switch (kind) {
            .character => |c| std.debug.print("{c}\n", .{ c }),
            else => std.debug.print("{s}\t{any}\n", .{ token, kind }),
        }
    }
}

