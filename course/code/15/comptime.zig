pub fn main() !void {
    try comptimeVariable.main();
    try comptimeExpression.main();
}

const DuckType = struct {
    // #region DuckType_max
    fn max(comptime T: type, a: T, b: T) T {
        return if (a > b) a else b;
    }
    // #endregion DuckType_max

    // #region DuckType_maxPlus
    fn maxPlus(comptime T: type, a: T, b: T) T {
        if (T == bool) {
            return a or b;
        } else if (a > b) {
            return a;
        } else {
            return b;
        }
    }
    // #endregion DuckType_maxPlus

    // #region DuckType_max_actual
    fn max_actual(a: bool, b: bool) bool {
        {
            return a or b;
        }
    }
    // #endregion DuckType_max_actual
};

const comptimeVariable = struct {
    // #region comptimeVariable
    const expect = @import("std").testing.expect;

    const CmdFn = struct {
        name: []const u8,
        func: fn (i32) i32,
    };

    // 这里的 cmd_fns 是一个常量，所以它是编译期可知的
    const cmd_fns = [_]CmdFn{
        CmdFn{ .name = "one", .func = one },
        CmdFn{ .name = "two", .func = two },
        CmdFn{ .name = "three", .func = three },
    };

    fn one(value: i32) i32 {
        return value + 1;
    }
    fn two(value: i32) i32 {
        return value + 2;
    }
    fn three(value: i32) i32 {
        return value + 3;
    }

    // #region comptimeVariable_default
    fn performFn(comptime prefix_char: u8, start_value: i32) i32 {
        var result: i32 = start_value;
        // 以下的变量 i 被标记为编译期已知的
        comptime var i = 0;
        // 这里将会被内联，实际编译出来的代码将不包含循环
        // 原因是cmd_fns是一个常量，那么代表它是编译期可知的
        // 也就是说整个循环的执行结果在编译期就可以确定
        inline while (i < cmd_fns.len) : (i += 1) {
            if (cmd_fns[i].name[0] == prefix_char) {
                result = cmd_fns[i].func(result);
            }
        }
        return result;
    }
    // #endregion comptimeVariable_default

    pub fn main() !void {
        try expect(performFn('t', 1) == 6);
        try expect(performFn('o', 0) == 1);
        try expect(performFn('w', 99) == 99);
    }
    // #endregion comptimeVariable

    // #region comptimeVariable_t
    fn performFn_for_t(start_value: i32) i32 {
        var result: i32 = start_value;
        result = two(result);
        result = three(result);
        return result;
    }
    // #endregion comptimeVariable_t

    // #region comptimeVariable_o
    fn performFn_for_o(start_value: i32) i32 {
        var result: i32 = start_value;
        result = one(result);
        return result;
    }
    // #endregion comptimeVariable_o

    // #region comptimeVariable_w
    fn performFn_for_w(start_value: i32) i32 {
        var result: i32 = start_value;
        _ = &result;
        return result;
    }
    // #endregion comptimeVariable_w
};

const comptimeExpression = struct {
    // #region comptimeExpression
    fn fibonacci(index: u32) u32 {
        if (index < 2) return index;
        return fibonacci(index - 1) + fibonacci(index - 2);
    }

    pub fn main() !void {
        const expect = @import("std").testing.expect;

        // 运行时测试
        try expect(fibonacci(7) == 13);

        // 编译期测试
        try comptime expect(fibonacci(7) == 13);
    }
    // #endregion comptimeExpression

    // #region comptimeExpression_container
    const c = add_comptime(1, 2);

    fn add_comptime(comptime a: usize, comptime b: usize) usize {
        return a + b;
    }
    // #endregion comptimeExpression_container
};

const GenericDataStruct = struct {
    // #region GenericDataStruct
    fn List(comptime T: type) type {
        return struct {
            items: []T,
            len: usize,
        };
    }

    var buffer: [10]i32 = undefined;

    var list = List(i32){
        .items = &buffer,
        .len = 0,
    };
    // #endregion GenericDataStruct

    // #region GenericDataStruct_node
    const Node = struct {
        next: ?*Node,
        name: []const u8,
    };

    var node_a = Node{
        .next = null,
        .name = "Node A",
    };

    var node_b = Node{
        .next = &node_a,
        .name = "Node B",
    };
    // #endregion GenericDataStruct_node
};
