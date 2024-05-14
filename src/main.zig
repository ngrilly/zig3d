const std = @import("std");
const raylib = @import("raylib.zig");
const quaternion = @import("quaternion.zig");
const light = @import("light.zig");
const Skybox = @import("Skybox.zig");

// Speeds in m/s
const minSpeed = -50;
const maxSpeed = 50;
const speedSensitivity = 5;
const strafeSpeed = 5;

const Player = struct {
    const maxAcceleration = 5;

    position: raylib.Vector3,
    velocity: raylib.Vector3 = raylib.Vector3Zero(),
    orientation: raylib.Quaternion,
    speed: f32 = 0,
    targetSpeed: f32 = 0,
    speedStop: bool = false, // TODO: find a better name
    accelerationMagnitude: f32 = 0,

    fn move(self: *Player, x: f32, y: f32, z: f32) void {
        const localMovement = raylib.Vector3{ .x = x, .y = y, .z = z };
        const worldMovement = raylib.Vector3RotateByQuaternion(localMovement, self.orientation);
        self.position = raylib.Vector3Add(self.position, worldMovement);
    }

    fn lookForwardVector(self: Player) raylib.Vector3 {
        const forward = raylib.Vector3{ .x = 0, .y = 0, .z = 1 };
        return raylib.Vector3Add(self.position, raylib.Vector3RotateByQuaternion(forward, self.orientation));
    }

    fn lookUpVector(self: Player) raylib.Vector3 {
        const up = raylib.Vector3{ .x = 0, .y = 1, .z = 0 };
        return raylib.Vector3RotateByQuaternion(up, self.orientation);
    }

    fn update(self: *Player) void {
        // When the ship changes direction, acceleration is required both toward the new direction and away from the current direction.
        const targetVelocity = raylib.Vector3RotateByQuaternion(.{ .x = 0, .y = 0, .z = self.targetSpeed }, self.orientation);
        var acceleration = raylib.Vector3Lerp(targetVelocity, raylib.Vector3Negate(self.velocity), 0.5);
        self.accelerationMagnitude = raylib.Vector3Length(acceleration);
        if (self.accelerationMagnitude > maxAcceleration) {
            acceleration = raylib.Vector3Scale(acceleration, maxAcceleration / self.accelerationMagnitude);
            self.accelerationMagnitude = maxAcceleration;
        }

        // TODO: GetFrameTime also called in processInputs: share?
        const frameTime = raylib.GetFrameTime();
        self.velocity = raylib.Vector3Add(self.velocity, raylib.Vector3Scale(acceleration, frameTime));
        self.position = raylib.Vector3Add(self.position, raylib.Vector3Scale(self.velocity, frameTime));

        self.speed = raylib.Vector3Length(self.velocity);
    }
};

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
    localToWorldMatrix: raylib.Matrix,
    mesh: raylib.Mesh,
    boundingSphereRadius: f32,

    fn deinit(self: Cube) void {
        raylib.UnloadMesh(self.mesh);
    }

    fn computeBoundingSphere(self: *Cube) void {
        var maxRadiusSquared: f32 = 0;
        for (0..@intCast(self.mesh.vertexCount)) |i| {
            const vertex = raylib.Vector3{
                .x = self.mesh.vertices[i * 3 + 0],
                .y = self.mesh.vertices[i * 3 + 1],
                .z = self.mesh.vertices[i * 3 + 2],
            };
            maxRadiusSquared = @max(maxRadiusSquared, raylib.Vector3LengthSqr(vertex));
        }
        self.boundingSphereRadius = @sqrt(maxRadiusSquared);
    }

    fn update(self: *Cube) void {
        self.position = raylib.Vector3Add(self.position, self.velocity);
        self.rotationAngle = @floatCast(self.rotationSpeed * raylib.GetTime());
        const matRotation = raylib.MatrixRotate(self.rotationAxis, self.rotationAngle * raylib.DEG2RAD);
        const matTranslation = raylib.MatrixTranslate(self.position.x, self.position.y, self.position.z);
        self.localToWorldMatrix = raylib.MatrixMultiply(matRotation, matTranslation);
    }

    /// Tests if the given ray is intersecting with the cube.
    fn isTargeted(self: Cube, ray: raylib.Ray) bool {
        const collisionSphere = raylib.GetRayCollisionSphere(ray, self.position, self.boundingSphereRadius);
        if (collisionSphere.hit and collisionSphere.distance > 0) {
            const collisionMesh = raylib.GetRayCollisionMesh(ray, self.mesh, self.localToWorldMatrix);
            if (collisionMesh.hit and collisionMesh.distance > 0) {
                return true;
            }
        }
        return false;
    }
};

pub fn main() !void {
    const initScreenWidth = 800;
    const initScreenHeight = 450;

    var prng = std.rand.DefaultPrng.init(0);
    const random = prng.random();

    raylib.SetConfigFlags(raylib.FLAG_WINDOW_RESIZABLE);
    raylib.InitWindow(initScreenWidth, initScreenHeight, "Zig 3D");
    raylib.SetExitKey(raylib.KEY_NULL);

    raylib.SetTargetFPS(60);

    raylib.InitAudioDevice();
    defer raylib.CloseAudioDevice();
    // We use a music stream because it offers looping, unlike a sound.
    const engineNoise = raylib.LoadMusicStream("resources/371282__nexotron__spaceship-engine-just-noise-normalized.wav");
    defer raylib.UnloadMusicStream(engineNoise);
    raylib.PlayMusicStream(engineNoise);

    // TODO: Better to use static or heap if too large for stack allocation? How is it done in TigerBeetle?
    var gameState = GameState.init(random);
    defer gameState.deinit();

    const renderer = Renderer.init();
    defer renderer.deinit();

    while (!raylib.WindowShouldClose()) {
        processInputs(&gameState.player);
        gameState.update();
        updateEngineNoise(engineNoise, gameState.player);
        const targetedCubeIndex = gameState.findTargetedCube();
        renderer.draw(gameState, targetedCubeIndex);
    }

    raylib.CloseWindow();
}

const cubeCount = 1000;
const cubeFieldDiameter = 500;
const cubeFieldDepth = 50;
const cubeMaxRotationSpeed = 30;

const GameState = struct {
    player: Player,
    cubes: [cubeCount]Cube,

    fn init(random: std.rand.Random) GameState {
        return .{
            .player = Player{
                .position = .{ .x = 0, .y = 2, .z = -15 },
                .orientation = raylib.QuaternionIdentity(),
            },
            .cubes = createCubes(random),
        };
    }

    fn deinit(self: GameState) void {
        defer for (self.cubes) |c| {
            c.deinit();
        };
    }

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
            c.mesh = raylib.GenMeshCube(c.size.x, c.size.y, c.size.z);
            c.computeBoundingSphere();
        }

        return cubes;
    }

    fn update(self: *GameState) void {
        self.player.update();

        for (&self.cubes) |*c| {
            c.update();
        }
    }

    /// Returns the index of the cube currently in the player's crosshair.
    fn findTargetedCube(self: GameState) ?u32 {
        const forward = raylib.Vector3{ .x = 0, .y = 0, .z = 1 };
        const ray = raylib.Ray{
            .position = self.player.position,
            .direction = raylib.Vector3RotateByQuaternion(forward, self.player.orientation),
        };

        var targetIndex: ?u32 = null;
        var targetDistanceSquared = std.math.floatMax(f32);

        // TODO: Only test cubes that are close enough?
        for (self.cubes, 0..) |c, i| {
            // If we already have found a cube, then skip the cubes behind.
            const distanceSquared = raylib.Vector3DistanceSqr(self.player.position, c.position);
            if (distanceSquared < targetDistanceSquared and c.isTargeted(ray)) {
                targetIndex = @intCast(i);
                targetDistanceSquared = distanceSquared;
            }
        }

        return targetIndex;
    }
};

fn processInputs(player: *Player) void {
    const frameTime = raylib.GetFrameTime();

    // TODO: support non-QWERTY keyboard?
    if (raylib.IsMouseButtonPressed(raylib.MOUSE_BUTTON_LEFT))
        raylib.DisableCursor();

    if (raylib.IsKeyPressed(raylib.KEY_ESCAPE))
        raylib.EnableCursor();

    if (raylib.IsKeyDown(raylib.KEY_W) and player.targetSpeed < maxSpeed)
        player.targetSpeed += speedSensitivity * frameTime;

    if (raylib.IsKeyDown(raylib.KEY_S) and player.targetSpeed > minSpeed and !player.speedStop) {
        const previousSpeed = player.targetSpeed;
        player.targetSpeed -= speedSensitivity * frameTime;
        // Player needs to release the key and press it again to reverse engine
        if (previousSpeed > 0 and player.targetSpeed <= 0) {
            player.targetSpeed = 0;
            player.speedStop = true;
        }
    }

    if (raylib.IsKeyReleased(raylib.KEY_S))
        player.speedStop = false;

    // TODO: Make strafe control realistic (simulate thrusters)
    if (raylib.IsKeyDown(raylib.KEY_A)) {
        player.move(strafeSpeed * frameTime, 0, 0);
    }

    if (raylib.IsKeyDown(raylib.KEY_D)) {
        player.move(-strafeSpeed * frameTime, 0, 0);
    }

    if (raylib.IsCursorHidden()) {
        const CAMERA_MOUSE_MOVE_SENSITIVITY = 0.005;
        const mousePositionDelta = raylib.GetMouseDelta();
        player.orientation = quaternion.rotateX(player.orientation, mousePositionDelta.y * CAMERA_MOUSE_MOVE_SENSITIVITY);
        player.orientation = quaternion.rotateY(player.orientation, -mousePositionDelta.x * CAMERA_MOUSE_MOVE_SENSITIVITY);
        // TODO: renormalize orientation to not accumulate errors?
    }
}

fn updateEngineNoise(engineNoise: raylib.Music, player: Player) void {
    const engineVolume = @abs(player.accelerationMagnitude) / Player.maxAcceleration;
    raylib.SetMusicVolume(engineNoise, engineVolume);
    raylib.UpdateMusicStream(engineNoise);
}

const Renderer = struct {
    skybox: Skybox,
    cubeShader: raylib.Shader,
    cubeMaterial: raylib.Material,
    lights: [light.MAX_LIGHTS]light.Light,

    fn init() Renderer {
        const cubeShader = raylib.LoadShaderFromMemory(@embedFile("shaders/cube.vs"), @embedFile("shaders/cube.fs"));
        cubeShader.locs[raylib.SHADER_LOC_VECTOR_VIEW] = raylib.GetShaderLocation(cubeShader, "viewPos");

        // Set ambient light level (some basic lighting)
        const ambientLoc = raylib.GetShaderLocation(cubeShader, "ambient");
        raylib.SetShaderValue(cubeShader, ambientLoc, &[4]f32{ 0.1, 0.1, 0.1, 1.0 }, raylib.SHADER_UNIFORM_VEC4);

        var cubeMaterial = raylib.LoadMaterialDefault();
        cubeMaterial.shader = cubeShader;

        // TODO: Are we copying the models array or is it optimized by the compiler?
        return .{
            .cubeShader = cubeShader,
            .cubeMaterial = cubeMaterial,
            .skybox = Skybox.init(),
            .lights = .{
                light.CreateLight(light.LightType.LIGHT_POINT, raylib.Vector3{ .x = -2, .y = 1, .z = -2 }, raylib.Vector3Zero(), raylib.YELLOW, cubeShader),
                light.CreateLight(light.LightType.LIGHT_POINT, raylib.Vector3{ .x = 2, .y = 1, .z = 2 }, raylib.Vector3Zero(), raylib.RED, cubeShader),
                light.CreateLight(light.LightType.LIGHT_POINT, raylib.Vector3{ .x = -2, .y = 1, .z = 2 }, raylib.Vector3Zero(), raylib.GREEN, cubeShader),
                light.CreateLight(light.LightType.LIGHT_POINT, raylib.Vector3{ .x = 2, .y = 1, .z = -2 }, raylib.Vector3Zero(), raylib.BLUE, cubeShader),
            },
        };
    }

    fn deinit(self: Renderer) void {
        raylib.UnloadShader(self.cubeShader);
        // TOOD: Do we need to unload cubeMaterial which is using LoadMaterialDefault()?
        // raylib.UnloadMaterial(self.cubeMaterial);
        self.skybox.deinit();
    }

    fn draw(self: Renderer, gameState: GameState, targetedCubeIndex: ?u32) void {
        const player = gameState.player;

        raylib.BeginDrawing();

        // Update the shader with the camera view vector (points towards { 0.0, 0.0, 0.0 })
        const cameraPos = [_]f32{ player.position.x, player.position.y, player.position.z };
        raylib.SetShaderValue(self.cubeShader, self.cubeShader.locs[raylib.SHADER_LOC_VECTOR_VIEW], &cameraPos, raylib.SHADER_UNIFORM_VEC3);

        const firstPersonCamera = raylib.Camera{
            .position = player.position,
            .target = player.lookForwardVector(),
            .up = player.lookUpVector(),
            .fovy = 60,
            .projection = raylib.CAMERA_PERSPECTIVE,
        };

        raylib.ClearBackground(raylib.BLACK);

        // TODO: Would it be better to be able to pass a view matrix instead of a Camera to BegingMode3D?
        raylib.BeginMode3D(firstPersonCamera);
        {
            self.skybox.draw();

            for (gameState.cubes) |c| {
                self.cubeMaterial.maps[raylib.MATERIAL_MAP_DIFFUSE].color = c.color;
                raylib.DrawMesh(c.mesh, self.cubeMaterial, c.localToWorldMatrix);
            }

            if (targetedCubeIndex) |i| {
                const c = gameState.cubes[i];
                raylib.DrawSphereWires(c.position, c.boundingSphereRadius, 6, 6, raylib.RED);
            }

            // Draw spheres to show where the lights are
            for (self.lights) |l| {
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
        raylib.DrawText(raylib.TextFormat("Speed: %.1f / %.1f m/s", player.speed, player.targetSpeed), raylib.GetScreenWidth() - 250, raylib.GetScreenHeight() - 30, 20, raylib.LIME);

        raylib.EndDrawing();
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
};
