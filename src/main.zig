const std = @import("std");
const raylib = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

const Cube = struct {
    position: raylib.Vector3,
    size: raylib.Vector3,
    color: raylib.Color,
    velocity: raylib.Vector3,
};

pub fn main() !void {
    const screenWidth = 800;
    const screenHeight = 450;

    raylib.SetConfigFlags(raylib.FLAG_WINDOW_RESIZABLE);
    raylib.InitWindow(screenWidth, screenHeight, "raylib [core] example - basic window");

    // TODO: Is it necessary, and why?
    raylib.SetTargetFPS(60);

    var camera = raylib.Camera{
        .position = raylib.Vector3{ .x = 0, .y = 2, .z = 4 },
        .target = raylib.Vector3{ .x = 0, .y = 2, .z = 0 },
        .up = raylib.Vector3{ .x = 0, .y = 1, .z = 0 },
        .fovy = 60,
        .projection = raylib.CAMERA_PERSPECTIVE,
    };

    // var speed: f32 = 0;

    var cubes = [_]Cube{
        .{
            .position = .{ .x = -16.0, .y = 2.5, .z = 0.0 },
            .size = .{ .x = 1.0, .y = 5.0, .z = 32.0 },
            .color = raylib.BLUE,
            .velocity = .{ .x = 0.01, .y = 0, .z = 0 },
        },
        .{
            .position = .{ .x = 16.0, .y = 2.5, .z = 0.0 },
            .size = .{ .x = 1.0, .y = 5.0, .z = 32.0 },
            .color = raylib.LIME,
            .velocity = .{ .x = 0, .y = 0, .z = 0 },
        },
        .{
            .position = .{ .x = 0, .y = 2.5, .z = 16.0 },
            .size = .{ .x = 32.0, .y = 5.0, .z = 1.0 },
            .color = raylib.GOLD,
            .velocity = .{ .x = 0, .y = 0, .z = 0 },
        },
    };

    while (!raylib.WindowShouldClose()) {
        // Update
        raylib.UpdateCamera(&camera, raylib.CAMERA_FIRST_PERSON);
        for (&cubes) |*c| {
            c.position = raylib.Vector3Add(c.position, c.velocity);
        }

        raylib.BeginDrawing();
        {
            raylib.ClearBackground(raylib.RAYWHITE);

            raylib.BeginMode3D(camera);
            {
                for (cubes) |c| {
                    raylib.DrawCubeV(c.position, c.size, c.color);
                }
            }
            raylib.EndMode3D();

            raylib.DrawText("Congrats! You created your first window!", 190, 200, 20, raylib.LIGHTGRAY);
        }
        raylib.EndDrawing();
    }

    raylib.CloseWindow();

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
