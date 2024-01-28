const std = @import("std");
const raylib = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
});

// TODO: I manually declare these raylib functions because I can't include rcamera.h. Find a better way. And namespace this in raylib.
pub extern fn CameraYaw(camera: *raylib.Camera, angle: f32, rotateAroundTarget: bool) void;
pub extern fn CameraPitch(camera: *raylib.Camera, angle: f32, lockView: bool, rotateAroundTarget: bool, rotateUp: bool) void;
pub extern fn CameraMoveForward(camera: *raylib.Camera, distance: f32, moveInWorldPlane: bool) void;

const minSpeed = -1;
const maxSpeed = 1;
const speedSensitivity = 0.1;

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

    raylib.SetTargetFPS(60);
    raylib.DisableCursor();

    var camera = raylib.Camera{
        .position = raylib.Vector3{ .x = 0, .y = 2, .z = -15 },
        .target = raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
        .up = raylib.Vector3{ .x = 0, .y = 1, .z = 0 },
        .fovy = 60,
        .projection = raylib.CAMERA_PERSPECTIVE,
    };

    // Load skybox model
    const cube = raylib.GenMeshCube(1.0, 1.0, 1.0);
    const skybox = raylib.LoadModelFromMesh(cube);
    defer raylib.UnloadModel(skybox);

    skybox.materials[0].shader = raylib.LoadShaderFromMemory(@embedFile("shaders/glsl330/skybox.vs"), @embedFile("shaders/glsl330/skybox.fs"));
    defer raylib.UnloadShader(skybox.materials[0].shader);

    raylib.SetShaderValue(skybox.materials[0].shader, raylib.GetShaderLocation(skybox.materials[0].shader, "environmentMap"), &raylib.MATERIAL_MAP_CUBEMAP, raylib.SHADER_UNIFORM_INT);
    raylib.SetShaderValue(skybox.materials[0].shader, raylib.GetShaderLocation(skybox.materials[0].shader, "doGamma"), &[1]c_int{0}, raylib.SHADER_UNIFORM_INT);
    raylib.SetShaderValue(skybox.materials[0].shader, raylib.GetShaderLocation(skybox.materials[0].shader, "vflipped"), &[1]c_int{0}, raylib.SHADER_UNIFORM_INT);

    const img = raylib.LoadImage("space-skybox-texture-mapping-cube-mapping-night-sky-24df7747449631f3f2a45fc630ae6ad0.png");
    skybox.materials[0].maps[raylib.MATERIAL_MAP_CUBEMAP].texture = raylib.LoadTextureCubemap(img, raylib.CUBEMAP_LAYOUT_AUTO_DETECT);
    raylib.UnloadImage(img);
    defer raylib.UnloadTexture(skybox.materials[0].maps[raylib.MATERIAL_MAP_CUBEMAP].texture);

    var speed: f32 = 0;
    var speedStop = false; // TODO: find a better name

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
        const frameTime = raylib.GetFrameTime();

        // Process inputs
        // TODO: support non-QWERTY keyboard?
        if (raylib.IsKeyDown(raylib.KEY_W) and speed < maxSpeed)
            speed += speedSensitivity * frameTime;
        if (raylib.IsKeyDown(raylib.KEY_S) and speed > minSpeed and !speedStop) {
            const previousSpeed = speed;
            speed -= speedSensitivity * frameTime;
            // Player needs to release the key and press it again to reverse engine
            if (previousSpeed > 0 and speed <= 0)
                speedStop = true;
        }
        if (raylib.IsKeyReleased(raylib.KEY_S))
            speedStop = false;

        const CAMERA_MOUSE_MOVE_SENSITIVITY = 0.005;
        const mousePositionDelta = raylib.GetMouseDelta();
        // const mousePosition = raylib.GetMousePosition();
        // const screenWidth: f32 = @floatFromInt(raylib.GetScreenWidth());
        // const screenHeight: f32 = @floatFromInt(raylib.GetScreenHeight());
        // const mousePositionXPercent = (screenWidth - mousePosition.x) / screenWidth;
        // const mousePositionYPercent = (screenHeight - mousePosition.y) / screenHeight;
        // CameraYaw(&camera, (mousePositionXPercent - 0.5) * CAMERA_MOUSE_MOVE_SENSITIVITY, false);
        // CameraPitch(&camera, (mousePositionYPercent - 0.5) * CAMERA_MOUSE_MOVE_SENSITIVITY, true, false, false);
        CameraYaw(&camera, -mousePositionDelta.x * CAMERA_MOUSE_MOVE_SENSITIVITY, false);
        CameraPitch(&camera, -mousePositionDelta.y * CAMERA_MOUSE_MOVE_SENSITIVITY, true, false, false);
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
                // Draw skybox. We are inside the cube, we need to disable backface culling!
                raylib.rlDisableBackfaceCulling();
                raylib.rlDisableDepthMask();
                raylib.DrawModel(skybox, raylib.Vector3{ .x = 0, .y = 0, .z = 0 }, 1.0, raylib.WHITE);
                raylib.rlEnableDepthMask();
                raylib.rlEnableBackfaceCulling();

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
            raylib.DrawFPS(10, 10);
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

    // const mousePosition = raylib.GetMousePosition();
    // raylib.DrawCircleLinesV(mousePosition, 10, raylib.WHITE);
}
