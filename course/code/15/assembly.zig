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
    pub fn main() noreturn {
        const msg = "hello world\n";
        _ = syscall3(SYS_write, STDOUT_FILENO, @intFromPtr(msg), msg.len);
        _ = syscall1(SYS_exit, 0);
        unreachable;
    }

    pub const SYS_write = 1;
    pub const SYS_exit = 60;

    pub const STDOUT_FILENO = 1;

    pub fn syscall1(number: usize, arg1: usize) usize {
        return asm volatile ("syscall"
            : [ret] "={rax}" (-> usize),
            : [number] "{rax}" (number),
              [arg1] "{rdi}" (arg1),
            : "rcx", "r11"
        );
    }

    pub fn syscall3(number: usize, arg1: usize, arg2: usize, arg3: usize) usize {
        return asm volatile ("syscall"
            : [ret] "={rax}" (-> usize),
            : [number] "{rax}" (number),
              [arg1] "{rdi}" (arg1),
              [arg2] "{rsi}" (arg2),
              [arg3] "{rdx}" (arg3),
            : "rcx", "r11"
        );
    }
    // #endregion inline_assembly
};
