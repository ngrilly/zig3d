const std = @import("std");
const raylib = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
});

// TODO: I manually declare these raylib functions because I can't include rcamera.h. Find a better way. And namespace this in raylib.
pub extern fn CameraYaw(camera: *raylib.Camera, angle: f32, rotateAroundTarget: bool) void;
pub extern fn CameraPitch(camera: *raylib.Camera, angle: f32, lockView: bool, rotateAroundTarget: bool, rotateUp: bool) void;
pub extern fn CameraMoveForward(camera: *raylib.Camera, distance: f32, moveInWorldPlane: bool) void;

const minSpeed = -10;
const maxSpeed = 100;

const Cube = struct {
    position: raylib.Vector3,
    size: raylib.Vector3,
    color: raylib.Color,
    velocity: raylib.Vector3,
};

pub fn main() !void {
    const initScreenWidth = 800;
    const initScreenHeight = 450;

    raylib.SetConfigFlags(raylib.FLAG_WINDOW_RESIZABLE);
    raylib.InitWindow(initScreenWidth, initScreenHeight, "raylib [core] example - basic window");

    // TODO: Is it necessary, and why?
    raylib.SetTargetFPS(60);

    var camera = raylib.Camera{
        .position = raylib.Vector3{ .x = 0, .y = 2, .z = -15 },
        .target = raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
        .up = raylib.Vector3{ .x = 0, .y = 1, .z = 0 },
        .fovy = 60,
        .projection = raylib.CAMERA_PERSPECTIVE,
    };

    var speed: f32 = 0;

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
        // Process inputs
        // TODO: support non-QWERTY keyboard?
        if (raylib.IsKeyDown(raylib.KEY_W) and speed < maxSpeed)
            speed += 0.01;
        if (raylib.IsKeyDown(raylib.KEY_S) and speed > minSpeed)
            speed -= 0.01;
        const CAMERA_MOUSE_MOVE_SENSITIVITY = 0.05;
        // const mousePositionDelta = raylib.GetMouseDelta();
        const mousePosition = raylib.GetMousePosition();
        const screenWidth: f32 = @floatFromInt(raylib.GetScreenWidth());
        const screenHeight: f32 = @floatFromInt(raylib.GetScreenHeight());
        const mousePositionXPercent = (screenWidth - mousePosition.x) / screenWidth;
        const mousePositionYPercent = (screenHeight - mousePosition.y) / screenHeight;
        CameraYaw(&camera, (mousePositionXPercent - 0.5) * CAMERA_MOUSE_MOVE_SENSITIVITY, false);
        CameraPitch(&camera, (mousePositionYPercent - 0.5) * CAMERA_MOUSE_MOVE_SENSITIVITY, true, false, false);
        // CameraYaw(&camera, -mousePositionDelta.x * CAMERA_MOUSE_MOVE_SENSITIVITY, false);
        // CameraPitch(&camera, -mousePositionDelta.y * CAMERA_MOUSE_MOVE_SENSITIVITY, true, false, false);
        // raylib.UpdateCamera(&camera, raylib.CAMERA_FIRST_PERSON);
        CameraMoveForward(&camera, speed, false);

        // Update
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

                raylib.DrawGrid(20, 1);
            }
            raylib.EndMode3D();

            drawCrosshair();
            raylib.DrawText(raylib.TextFormat("Speed: %f", speed), raylib.GetScreenWidth() - 220, raylib.GetScreenHeight() - 30, 20, raylib.LIME);
        }
        raylib.EndDrawing();
    }

    raylib.CloseWindow();
}

fn drawCrosshair() void {
    const crosshairSize = 10;
    const screenWidth = raylib.GetScreenWidth();
    const screenHeight = raylib.GetScreenHeight();
    const screenCenterX = @divTrunc(screenWidth, 2);
    const screenCenterY = @divTrunc(screenHeight, 2);
    raylib.DrawLine(screenCenterX, screenCenterY + crosshairSize, screenCenterX, screenCenterY - crosshairSize, raylib.WHITE);
    raylib.DrawLine(screenCenterX + crosshairSize, screenCenterY, screenCenterX - crosshairSize, screenCenterY, raylib.WHITE);
}
