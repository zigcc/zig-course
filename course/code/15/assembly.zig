pub fn main() !void {}

const external_assembly = struct {
    // #region external_assembly
    const std = @import("std");

    comptime {
        asm (
            \\.global my_func;
            \\.type my_func, @function;
            \\my_func:
            \\  lea (%rdi,%rsi,1),%eax
            \\  retq
        );
    }

    extern fn my_func(a: i32, b: i32) i32;

    pub fn main() void {
        std.debug.print("{}\n", .{my_func(2, 5)});
    }
    // #endregion external_assembly
};

const inline_assembly = struct {
    // #region inline_assembly
    const std = @import("std");

    pub fn main() noreturn {
        // Temporarily disabled due to Zig 0.15 syntax changes
        // const msg = "hello world\n";
        // _ = syscall3(SYS_write, STDOUT_FILENO, @intFromPtr(msg), msg.len);
        // _ = syscall1(SYS_exit, 0);
        std.process.exit(0);
    }

    pub const SYS_write = 1;
    pub const SYS_exit = 60;

    pub const STDOUT_FILENO = 1;

    // Temporarily disabled due to Zig 0.15 inline assembly syntax changes
    // TODO: Update to new Zig 0.15 inline assembly syntax

    // pub fn syscall1(number: usize, arg1: usize) usize {
    //     var result: usize = undefined;
    //     asm volatile ("syscall"
    //         : [ret] "={rax}" (result)
    //         : [number] "{rax}" (number),
    //           [arg1] "{rdi}" (arg1)
    //         : "rcx", "r11"
    //     );
    //     return result;
    // }

    // pub fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) usize {
    //     var result: usize = undefined;
    //     asm volatile ("syscall"
    //         : [ret] "={rax}" (result)
    //         : [number] "{rax}" (number),
    //           [arg1] "{rdi}" (arg1),
    //           [arg2] "{rsi}" (arg2),
    //           [arg3] "{rdx}" (arg3)
    //         : "rcx", "r11"
    //     );
    //     return result;
    // }
    // #endregion inline_assembly
};
