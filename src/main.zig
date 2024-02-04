const std = @import("std");
const raylib = @import("raylib.zig");
const light = @import("light.zig");
const Skybox = @import("Skybox.zig");

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
    // TODO: rename rotationAxis to orientation?
    rotationAxis: raylib.Vector3 = .{ .x = 0, .y = 0, .z = 0 },
    // TODO: rename rotationSpeed to angularVelocity?
    rotationSpeed: f32,
    rotationAngle: f32,
};

pub fn main() !void {
    const initScreenWidth = 800;
    const initScreenHeight = 450;

    var prng = std.rand.DefaultPrng.init(0);
    const random = prng.random();

    raylib.SetConfigFlags(raylib.FLAG_WINDOW_RESIZABLE);
    raylib.InitWindow(initScreenWidth, initScreenHeight, "raylib [core] example - basic window");
    raylib.SetExitKey(raylib.KEY_NULL);

    raylib.SetTargetFPS(60);

    raylib.InitAudioDevice();
    defer raylib.CloseAudioDevice();
    // We use a music stream because it offers looping, unlike a sound.
    const engineNoise = raylib.LoadMusicStream("resources/371282__nexotron__spaceship-engine-just-noise-normalized.wav");
    defer raylib.UnloadMusicStream(engineNoise);
    raylib.PlayMusicStream(engineNoise);

    var camera = raylib.Camera{
        .position = raylib.Vector3{ .x = 0, .y = 2, .z = -15 },
        .target = raylib.Vector3{ .x = 0, .y = 0, .z = 0 },
        .up = raylib.Vector3{ .x = 0, .y = 1, .z = 0 },
        .fovy = 60,
        .projection = raylib.CAMERA_PERSPECTIVE,
    };

    // Load skybox model
    const skybox = Skybox.init();
    defer skybox.deinit();

    var speed: f32 = 0;
    var speedStop = false; // TODO: find a better name

    const cubeCount = 1000;
    const cubeFieldDiameter = 500;
    const cubeFieldDepth = 50;
    const cubeMaxRotationSpeed = 30;

    var cubes: [cubeCount]Cube = undefined;
    for (&cubes) |*c| {
        c.position = .{
            .x = (random.float(f32) - 0.5) * cubeFieldDiameter,
            .y = (random.float(f32) - 0.5) * cubeFieldDepth,
            .z = random.float(f32) * cubeFieldDiameter,
        };
        c.size = .{
            .x = 1 + random.float(f32) * 3,
            .y = 1 + random.float(f32) * 3,
            .z = 1 + random.float(f32) * 3,
        };
        c.velocity = .{ .x = 0.0, .y = 0, .z = 0 };
        c.rotationAxis = .{ .x = random.float(f32), .y = random.float(f32), .z = random.float(f32) };
        c.rotationSpeed = (2 * random.float(f32) - 1) * cubeMaxRotationSpeed;
        c.rotationAngle = 0;
        c.color = raylib.BLUE;
        // c.color = raylib.LIME;
        // c.color = raylib.GOLD;
    }

    const cubeShader = raylib.LoadShaderFromMemory(@embedFile("shaders/cube.vs"), @embedFile("shaders/cube.fs"));
    defer raylib.UnloadShader(cubeShader);
    cubeShader.locs[raylib.SHADER_LOC_VECTOR_VIEW] = raylib.GetShaderLocation(cubeShader, "viewPos");

    // Set ambient light level (some basic lighting)
    const ambientLoc = raylib.GetShaderLocation(cubeShader, "ambient");
    raylib.SetShaderValue(cubeShader, ambientLoc, &[4]f32{ 0.1, 0.1, 0.1, 1.0 }, raylib.SHADER_UNIFORM_VEC4);

    // Create lights
    const lights = [_]light.Light{
        light.CreateLight(light.LightType.LIGHT_POINT, raylib.Vector3{ .x = -2, .y = 1, .z = -2 }, raylib.Vector3Zero(), raylib.YELLOW, cubeShader),
        light.CreateLight(light.LightType.LIGHT_POINT, raylib.Vector3{ .x = 2, .y = 1, .z = 2 }, raylib.Vector3Zero(), raylib.RED, cubeShader),
        light.CreateLight(light.LightType.LIGHT_POINT, raylib.Vector3{ .x = -2, .y = 1, .z = 2 }, raylib.Vector3Zero(), raylib.GREEN, cubeShader),
        light.CreateLight(light.LightType.LIGHT_POINT, raylib.Vector3{ .x = 2, .y = 1, .z = -2 }, raylib.Vector3Zero(), raylib.BLUE, cubeShader),
    };

    // TODO: is there a way to avoid undefined?
    var models: [cubes.len]raylib.Model = undefined;
    for (cubes, &models) |c, *m| {
        const mesh = raylib.GenMeshCube(c.size.x, c.size.y, c.size.z);
        m.* = raylib.LoadModelFromMesh(mesh);
        m.materials[0].shader = cubeShader;
    }

    defer for (models) |m| {
        raylib.UnloadModel(m);
    };

    while (!raylib.WindowShouldClose()) {
        const frameTime = raylib.GetFrameTime();

        // Process inputs
        // TODO: support non-QWERTY keyboard?
        if (raylib.IsMouseButtonPressed(raylib.MOUSE_BUTTON_LEFT))
            raylib.DisableCursor();
        if (raylib.IsKeyPressed(raylib.KEY_ESCAPE))
            raylib.EnableCursor();
        if (raylib.IsKeyDown(raylib.KEY_W) and speed < maxSpeed)
            speed += speedSensitivity * frameTime;
        if (raylib.IsKeyDown(raylib.KEY_S) and speed > minSpeed and !speedStop) {
            const previousSpeed = speed;
            speed -= speedSensitivity * frameTime;
            // Player needs to release the key and press it again to reverse engine
            if (previousSpeed > 0 and speed <= 0) {
                speed = 0;
                speedStop = true;
            }
        }
        if (raylib.IsKeyReleased(raylib.KEY_S))
            speedStop = false;

        if (raylib.IsCursorHidden()) {
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
        }

        // Update physics
        for (&cubes) |*c| {
            c.position = raylib.Vector3Add(c.position, c.velocity);
            c.rotationAngle = @floatCast(c.rotationSpeed * raylib.GetTime());
        }

        // Update audio
        const engineVolume = @abs(speed) / maxSpeed;
        raylib.SetMusicVolume(engineNoise, engineVolume);
        raylib.UpdateMusicStream(engineNoise);

        // Update the shader with the camera view vector (points towards { 0.0, 0.0, 0.0 })
        const cameraPos = [_]f32{ camera.position.x, camera.position.y, camera.position.z };
        raylib.SetShaderValue(cubeShader, cubeShader.locs[raylib.SHADER_LOC_VECTOR_VIEW], &cameraPos, raylib.SHADER_UNIFORM_VEC3);

        // Draw
        raylib.BeginDrawing();
        {
            raylib.ClearBackground(raylib.BLACK);

            raylib.BeginMode3D(camera);
            {
                skybox.draw();

                for (cubes, models) |c, model| {
                    const scale = raylib.Vector3{ .x = 1, .y = 1, .z = 1 };
                    raylib.DrawModelEx(model, c.position, c.rotationAxis, c.rotationAngle, scale, c.color);
                }

                // Draw spheres to show where the lights are
                for (lights) |l| {
                    if (l.enabled)
                        raylib.DrawSphereEx(l.position, 0.2, 8, 8, l.color)
                    else
                        raylib.DrawSphereWires(l.position, 0.2, 8, 8, raylib.ColorAlpha(l.color, 0.3));
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

    // TODO: Should we visualize yaw and pitch changes with a circle?
    // const mousePosition = raylib.GetMousePosition();
    // raylib.DrawCircleLinesV(mousePosition, 10, raylib.WHITE);
}
