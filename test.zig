const std = @import("std");
extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;
pub fn main() !void {
    _ = setenv("LC_ALL", "C", 1);
}
