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
        .position = raylib.Vector3{ .x = 0, .y = 2, .z = -15 },
        .target = raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
        .up = raylib.Vector3{ .x = 0, .y = 1, .z = 0 },
        .fovy = 60,
        .projection = raylib.CAMERA_PERSPECTIVE,
    };

    // var speed: f32 = 0;

    // TODO: add orientation and angularVelocity (equals rotation axis + rotation speed)
    var cubes = [_]Cube{
        .{
            .position = .{ .x = -10.0, .y = 0, .z = 0.0 },
            .size = .{ .x = 1.0, .y = 2.0, .z = 4.0 },
            .color = raylib.BLUE,
            .velocity = .{ .x = 0.0, .y = 0, .z = 0 },
        },
        .{
            .position = .{ .x = 10.0, .y = 0, .z = 0.0 },
            .size = .{ .x = 1.0, .y = 2.0, .z = 4.0 },
            .color = raylib.LIME,
            .velocity = .{ .x = 0, .y = 0, .z = 0 },
        },
        .{
            .position = .{ .x = 0, .y = 0, .z = 10.0 },
            .size = .{ .x = 4.0, .y = 2.0, .z = 1.0 },
            .color = raylib.GOLD,
            .velocity = .{ .x = 0, .y = 0, .z = 0 },
        },
    };

    // TODO: is there a way to avoid undefined?
    var models: [cubes.len]raylib.Model = undefined;
    for (cubes, &models) |c, *m| {
        const mesh = raylib.GenMeshCube(c.size.x, c.size.y, c.size.z);
        m.* = raylib.LoadModelFromMesh(mesh);
    }

    defer for (models) |m| {
        raylib.UnloadModel(m);
    };

    while (!raylib.WindowShouldClose()) {
        // Update
        raylib.UpdateCamera(&camera, raylib.CAMERA_FIRST_PERSON);
        for (&cubes) |*c| {
            c.position = raylib.Vector3Add(c.position, c.velocity);
        }

        raylib.BeginDrawing();
        {
            raylib.ClearBackground(raylib.BLACK);

            raylib.BeginMode3D(camera);
            {
                for (cubes, models) |c, model| {
                    const rotationAxis = raylib.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 };
                    const rotationAngle: f32 = @floatCast(30.0 * raylib.GetTime());
                    const scale = raylib.Vector3{ .x = 1, .y = 1, .z = 1 };
                    raylib.DrawModelEx(model, c.position, rotationAxis, rotationAngle, scale, c.color);
                }

                // raylib.DrawGrid(20, 1);
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
    _ = stdout; // autofix

    try bw.flush(); // don't forget to flush!
}
