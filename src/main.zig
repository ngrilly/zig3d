const std = @import("std");
const raylib = @import("raylib.zig");
const light = @import("light.zig");
const Skybox = @import("Skybox.zig");

// Speeds in m/s
const minSpeed = -50;
const maxSpeed = 50;
const speedSensitivity = 5;
const strafeSpeed = 5;

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

    var cubes = createCubes(random);

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
        // TODO: Make strafe control realistic (simulate thrusters)
        if (raylib.IsKeyDown(raylib.KEY_A)) {
            cameraMoveRight(&camera, -strafeSpeed * frameTime);
        }
        if (raylib.IsKeyDown(raylib.KEY_D)) {
            cameraMoveRight(&camera, strafeSpeed * frameTime);
        }

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
            cameraYaw(&camera, -mousePositionDelta.x * CAMERA_MOUSE_MOVE_SENSITIVITY);
            cameraPitch(&camera, -mousePositionDelta.y * CAMERA_MOUSE_MOVE_SENSITIVITY, true, false);
            // raylib.UpdateCamera(&camera, raylib.CAMERA_FIRST_PERSON);
            cameraMoveForward(&camera, speed * frameTime);
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
            raylib.DrawText(raylib.TextFormat("Speed: %.1f m/s", speed), raylib.GetScreenWidth() - 220, raylib.GetScreenHeight() - 30, 20, raylib.LIME);
        }
        raylib.EndDrawing();
    }

    raylib.CloseWindow();
}

const cubeCount = 1000;
const cubeFieldDiameter = 500;
const cubeFieldDepth = 50;
const cubeMaxRotationSpeed = 30;

/// Creates a field of random cubes.
fn createCubes(random: std.rand.Random) [cubeCount]Cube {
    // TODO: Verify that according to Zig Result Location Semantics the cubes are not copied.

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

    return cubes;
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

//--------------------------------------------------------------------------------
// Camera (ported from raylib rcamera.h to Zig with some simplifications)
//--------------------------------------------------------------------------------

// Returns the cameras forward vector (normalized)
fn getCameraForward(camera: *raylib.Camera) raylib.Vector3 {
    return raylib.Vector3Normalize(raylib.Vector3Subtract(camera.target, camera.position));
}

// Returns the cameras up vector (normalized)
// Note: The up vector might not be perpendicular to the forward vector
fn getCameraUp(camera: *raylib.Camera) raylib.Vector3 {
    return raylib.Vector3Normalize(camera.up);
}

// Returns the cameras right vector (normalized)
fn getCameraRight(camera: *raylib.Camera) raylib.Vector3 {
    const forward = getCameraForward(camera);
    const up = getCameraUp(camera);

    return raylib.Vector3CrossProduct(forward, up);
}

// Moves the camera in its forward direction
fn cameraMoveForward(camera: *raylib.Camera, distance: f32) void {
    var forward = getCameraForward(camera);

    // Scale by distance
    forward = raylib.Vector3Scale(forward, distance);

    // Move position and target
    camera.position = raylib.Vector3Add(camera.position, forward);
    camera.target = raylib.Vector3Add(camera.target, forward);
}

// Moves the camera target in its current right direction
fn cameraMoveRight(camera: *raylib.Camera, distance: f32) void {
    var right = getCameraRight(camera);

    // Scale by distance
    right = raylib.Vector3Scale(right, distance);

    // Move position and target
    camera.position = raylib.Vector3Add(camera.position, right);
    camera.target = raylib.Vector3Add(camera.target, right);
}

// Rotates the camera around its up vector
// Yaw is "looking left and right"
// Note: angle must be provided in radians
fn cameraYaw(camera: *raylib.Camera, angle: f32) void {
    // Rotation axis
    const up = getCameraUp(camera);

    // View vector
    var targetPosition = raylib.Vector3Subtract(camera.target, camera.position);

    // Rotate view vector around up axis
    targetPosition = raylib.Vector3RotateByAxisAngle(targetPosition, up, angle);

    // Move target relative to position
    camera.target = raylib.Vector3Add(camera.position, targetPosition);
}

// Rotates the camera around its right vector, pitch is "looking up and down"
//  - lockView prevents camera overrotation (aka "somersaults")
//  - rotateAroundTarget defines if rotation is around target or around its position
//  - rotateUp rotates the up direction as well (typically only usefull in CAMERA_FREE)
// NOTE: angle must be provided in radians
fn cameraPitch(camera: *raylib.Camera, requestedAngle: f32, lockView: bool, rotateUp: bool) void {
    // View vector
    var targetPosition = raylib.Vector3Subtract(camera.target, camera.position);

    var angle = requestedAngle;
    if (lockView) {
        // In these camera modes we clamp the Pitch angle
        // to allow only viewing straight up or down.

        // Clamp view up
        const up = getCameraUp(camera);
        var maxAngleUp = raylib.Vector3Angle(up, targetPosition);
        maxAngleUp -= 0.001; // avoid numerical errors
        if (angle > maxAngleUp) angle = maxAngleUp;

        // Clamp view down
        var maxAngleDown = raylib.Vector3Angle(raylib.Vector3Negate(up), targetPosition);
        maxAngleDown *= -1.0; // downwards angle is negative
        maxAngleDown += 0.001; // avoid numerical errors
        if (angle < maxAngleDown) angle = maxAngleDown;
    }

    // Rotation axis
    const right = getCameraRight(camera);

    // Rotate view vector around right axis
    targetPosition = raylib.Vector3RotateByAxisAngle(targetPosition, right, angle);

    // Move target relative to position
    camera.target = raylib.Vector3Add(camera.position, targetPosition);

    if (rotateUp) {
        // Rotate up direction around right axis
        camera.up = raylib.Vector3RotateByAxisAngle(camera.up, right, angle);
    }
}
