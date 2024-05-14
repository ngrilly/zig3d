const std = @import("std");
const raylib = @import("raylib.zig");
const quaternion = @import("quaternion.zig");
const light = @import("light.zig");
const Skybox = @import("Skybox.zig");

// Speeds in m/s
const min_speed = -50;
const max_speed = 50;
const speed_sensitivity = 5;
const strafe_speed = 5;

const Player = struct {
    const max_acceleration = 5;

    position: raylib.Vector3,
    velocity: raylib.Vector3 = raylib.Vector3Zero(),
    orientation: raylib.Quaternion,
    speed: f32 = 0,
    target_speed: f32 = 0,
    speed_stop: bool = false, // TODO: find a better name
    acceleration_magnitude: f32 = 0,

    fn move(self: *Player, x: f32, y: f32, z: f32) void {
        const local_movement = raylib.Vector3{ .x = x, .y = y, .z = z };
        const world_movement = raylib.Vector3RotateByQuaternion(local_movement, self.orientation);
        self.position = raylib.Vector3Add(self.position, world_movement);
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
        const target_velocity = raylib.Vector3RotateByQuaternion(.{ .x = 0, .y = 0, .z = self.target_speed }, self.orientation);
        var acceleration = raylib.Vector3Lerp(target_velocity, raylib.Vector3Negate(self.velocity), 0.5);
        self.acceleration_magnitude = raylib.Vector3Length(acceleration);
        if (self.acceleration_magnitude > max_acceleration) {
            acceleration = raylib.Vector3Scale(acceleration, max_acceleration / self.acceleration_magnitude);
            self.acceleration_magnitude = max_acceleration;
        }

        // TODO: GetFrameTime also called in processInputs: share?
        const frame_time = raylib.GetFrameTime();
        self.velocity = raylib.Vector3Add(self.velocity, raylib.Vector3Scale(acceleration, frame_time));
        self.position = raylib.Vector3Add(self.position, raylib.Vector3Scale(self.velocity, frame_time));

        self.speed = raylib.Vector3Length(self.velocity);
    }
};

const Cube = struct {
    position: raylib.Vector3,
    size: raylib.Vector3,
    color: raylib.Color,
    velocity: raylib.Vector3,
    // TODO: rename rotation_axis to orientation?
    rotation_axis: raylib.Vector3 = .{ .x = 0, .y = 0, .z = 0 },
    // TODO: rename rotation_speed to angular_velocity?
    rotation_speed: f32,
    rotation_angle: f32,
    local_to_world_matrix: raylib.Matrix,
    mesh: raylib.Mesh,
    bounding_sphere_radius: f32,

    fn deinit(self: Cube) void {
        raylib.UnloadMesh(self.mesh);
    }

    fn computeBoundingSphere(self: *Cube) void {
        var max_radius_squared: f32 = 0;
        for (0..@intCast(self.mesh.vertexCount)) |i| {
            const vertex = raylib.Vector3{
                .x = self.mesh.vertices[i * 3 + 0],
                .y = self.mesh.vertices[i * 3 + 1],
                .z = self.mesh.vertices[i * 3 + 2],
            };
            max_radius_squared = @max(max_radius_squared, raylib.Vector3LengthSqr(vertex));
        }
        self.bounding_sphere_radius = @sqrt(max_radius_squared);
    }

    fn update(self: *Cube) void {
        self.position = raylib.Vector3Add(self.position, self.velocity);
        self.rotation_angle = @floatCast(self.rotation_speed * raylib.GetTime());
        const mat_rotation = raylib.MatrixRotate(self.rotation_axis, self.rotation_angle * raylib.DEG2RAD);
        const mat_translation = raylib.MatrixTranslate(self.position.x, self.position.y, self.position.z);
        self.local_to_world_matrix = raylib.MatrixMultiply(mat_rotation, mat_translation);
    }

    /// Tests if the given ray is intersecting with the cube.
    fn isTargeted(self: Cube, ray: raylib.Ray) bool {
        const collision_sphere = raylib.GetRayCollisionSphere(ray, self.position, self.bounding_sphere_radius);
        if (collision_sphere.hit and collision_sphere.distance > 0) {
            const collision_mesh = raylib.GetRayCollisionMesh(ray, self.mesh, self.local_to_world_matrix);
            if (collision_mesh.hit and collision_mesh.distance > 0) {
                return true;
            }
        }
        return false;
    }
};

pub fn main() !void {
    const init_screen_width = 800;
    const init_screen_height = 450;

    var prng = std.rand.DefaultPrng.init(0);
    const random = prng.random();

    raylib.SetConfigFlags(raylib.FLAG_WINDOW_RESIZABLE);
    raylib.SetExitKey(raylib.KEY_NULL);

    raylib.InitWindow(init_screen_width, init_screen_height, "Zig 3D");
    defer raylib.CloseWindow();

    raylib.SetTargetFPS(60);

    raylib.InitAudioDevice();
    defer raylib.CloseAudioDevice();
    // We use a music stream because it offers looping, unlike a sound.
    const engine_noise = raylib.LoadMusicStream("resources/371282__nexotron__spaceship-engine-just-noise-normalized.wav");
    defer raylib.UnloadMusicStream(engine_noise);
    raylib.PlayMusicStream(engine_noise);

    // TODO: Better to use static or heap if too large for stack allocation? How is it done in TigerBeetle?
    var game_state = GameState.init(random);
    defer game_state.deinit();

    const renderer = Renderer.init();
    defer renderer.deinit();

    while (!raylib.WindowShouldClose()) {
        processInputs(&game_state.player);
        game_state.update();
        updateEngineNoise(engine_noise, game_state.player);
        const targeted_cube_index = game_state.findTargetedCube();
        renderer.draw(game_state, targeted_cube_index);
    }
}

const cube_count = 1000;
const cube_field_diameter = 500;
const cube_field_depth = 50;
const cube_max_rotation_speed = 30;

const GameState = struct {
    player: Player,
    cubes: [cube_count]Cube,

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
    fn createCubes(random: std.rand.Random) [cube_count]Cube {
        // TODO: Verify that according to Zig Result Location Semantics the cubes are not copied.

        var cubes: [cube_count]Cube = undefined;

        for (&cubes) |*c| {
            c.position = .{
                .x = (random.float(f32) - 0.5) * cube_field_diameter,
                .y = (random.float(f32) - 0.5) * cube_field_depth,
                .z = random.float(f32) * cube_field_diameter,
            };
            c.size = .{
                .x = 1 + random.float(f32) * 3,
                .y = 1 + random.float(f32) * 3,
                .z = 1 + random.float(f32) * 3,
            };
            c.velocity = .{ .x = 0.0, .y = 0, .z = 0 };
            c.rotation_axis = .{ .x = random.float(f32), .y = random.float(f32), .z = random.float(f32) };
            c.rotation_speed = (2 * random.float(f32) - 1) * cube_max_rotation_speed;
            c.rotation_angle = 0;
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

        var target_index: ?u32 = null;
        var target_distance_squared = std.math.floatMax(f32);

        // TODO: Only test cubes that are close enough?
        for (self.cubes, 0..) |c, i| {
            // If we already have found a cube, then skip the cubes behind.
            const distance_squared = raylib.Vector3DistanceSqr(self.player.position, c.position);
            if (distance_squared < target_distance_squared and c.isTargeted(ray)) {
                target_index = @intCast(i);
                target_distance_squared = distance_squared;
            }
        }

        return target_index;
    }
};

fn processInputs(player: *Player) void {
    const frame_time = raylib.GetFrameTime();

    // TODO: support non-QWERTY keyboard?
    if (raylib.IsMouseButtonPressed(raylib.MOUSE_BUTTON_LEFT))
        raylib.DisableCursor();

    if (raylib.IsKeyPressed(raylib.KEY_ESCAPE))
        raylib.EnableCursor();

    if (raylib.IsKeyDown(raylib.KEY_W) and player.target_speed < max_speed)
        player.target_speed += speed_sensitivity * frame_time;

    if (raylib.IsKeyDown(raylib.KEY_S) and player.target_speed > min_speed and !player.speed_stop) {
        const previous_speed = player.target_speed;
        player.target_speed -= speed_sensitivity * frame_time;
        // Player needs to release the key and press it again to reverse engine
        if (previous_speed > 0 and player.target_speed <= 0) {
            player.target_speed = 0;
            player.speed_stop = true;
        }
    }

    if (raylib.IsKeyReleased(raylib.KEY_S))
        player.speed_stop = false;

    // TODO: Make strafe control realistic (simulate thrusters)
    if (raylib.IsKeyDown(raylib.KEY_A)) {
        player.move(strafe_speed * frame_time, 0, 0);
    }

    if (raylib.IsKeyDown(raylib.KEY_D)) {
        player.move(-strafe_speed * frame_time, 0, 0);
    }

    if (raylib.IsCursorHidden()) {
        const CAMERA_MOUSE_MOVE_SENSITIVITY = 0.005;
        const mouse_position_delta = raylib.GetMouseDelta();
        player.orientation = quaternion.rotateX(player.orientation, mouse_position_delta.y * CAMERA_MOUSE_MOVE_SENSITIVITY);
        player.orientation = quaternion.rotateY(player.orientation, -mouse_position_delta.x * CAMERA_MOUSE_MOVE_SENSITIVITY);
        // TODO: renormalize orientation to not accumulate errors?
    }
}

fn updateEngineNoise(engineNoise: raylib.Music, player: Player) void {
    const engine_volume = @abs(player.acceleration_magnitude) / Player.max_acceleration;
    raylib.SetMusicVolume(engineNoise, engine_volume);
    raylib.UpdateMusicStream(engineNoise);
}

const Renderer = struct {
    skybox: Skybox,
    cube_shader: raylib.Shader,
    cube_material: raylib.Material,
    lights: [light.MAX_LIGHTS]light.Light,

    fn init() Renderer {
        const cube_shader = raylib.LoadShaderFromMemory(@embedFile("shaders/cube.vs"), @embedFile("shaders/cube.fs"));
        cube_shader.locs[raylib.SHADER_LOC_VECTOR_VIEW] = raylib.GetShaderLocation(cube_shader, "viewPos");

        // Set ambient light level (some basic lighting)
        const ambient_loc = raylib.GetShaderLocation(cube_shader, "ambient");
        raylib.SetShaderValue(cube_shader, ambient_loc, &[4]f32{ 0.1, 0.1, 0.1, 1.0 }, raylib.SHADER_UNIFORM_VEC4);

        var cube_material = raylib.LoadMaterialDefault();
        cube_material.shader = cube_shader;

        // TODO: Are we copying the models array or is it optimized by the compiler?
        return .{
            .cube_shader = cube_shader,
            .cube_material = cube_material,
            .skybox = Skybox.init(),
            .lights = .{
                light.CreateLight(light.LightType.LIGHT_POINT, raylib.Vector3{ .x = -2, .y = 1, .z = -2 }, raylib.Vector3Zero(), raylib.YELLOW, cube_shader),
                light.CreateLight(light.LightType.LIGHT_POINT, raylib.Vector3{ .x = 2, .y = 1, .z = 2 }, raylib.Vector3Zero(), raylib.RED, cube_shader),
                light.CreateLight(light.LightType.LIGHT_POINT, raylib.Vector3{ .x = -2, .y = 1, .z = 2 }, raylib.Vector3Zero(), raylib.GREEN, cube_shader),
                light.CreateLight(light.LightType.LIGHT_POINT, raylib.Vector3{ .x = 2, .y = 1, .z = -2 }, raylib.Vector3Zero(), raylib.BLUE, cube_shader),
            },
        };
    }

    fn deinit(self: Renderer) void {
        raylib.UnloadShader(self.cube_shader);
        // TOOD: Do we need to unload cubeMaterial which is using LoadMaterialDefault()?
        // raylib.UnloadMaterial(self.cubeMaterial);
        self.skybox.deinit();
    }

    fn draw(self: Renderer, game_state: GameState, targeted_cube_index: ?u32) void {
        const player = game_state.player;

        raylib.BeginDrawing();

        // Update the shader with the camera view vector (points towards { 0.0, 0.0, 0.0 })
        const camera_pos = [_]f32{ player.position.x, player.position.y, player.position.z };
        raylib.SetShaderValue(self.cube_shader, self.cube_shader.locs[raylib.SHADER_LOC_VECTOR_VIEW], &camera_pos, raylib.SHADER_UNIFORM_VEC3);

        const first_person_camera = raylib.Camera{
            .position = player.position,
            .target = player.lookForwardVector(),
            .up = player.lookUpVector(),
            .fovy = 60,
            .projection = raylib.CAMERA_PERSPECTIVE,
        };

        raylib.ClearBackground(raylib.BLACK);

        // TODO: Would it be better to be able to pass a view matrix instead of a Camera to BegingMode3D?
        raylib.BeginMode3D(first_person_camera);
        {
            self.skybox.draw();

            for (game_state.cubes) |c| {
                self.cube_material.maps[raylib.MATERIAL_MAP_DIFFUSE].color = c.color;
                raylib.DrawMesh(c.mesh, self.cube_material, c.local_to_world_matrix);
            }

            if (targeted_cube_index) |i| {
                const c = game_state.cubes[i];
                raylib.DrawSphereWires(c.position, c.bounding_sphere_radius, 6, 6, raylib.RED);
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
        raylib.DrawText(raylib.TextFormat("Speed: %.1f / %.1f m/s", player.speed, player.target_speed), raylib.GetScreenWidth() - 250, raylib.GetScreenHeight() - 30, 20, raylib.LIME);

        raylib.EndDrawing();
    }

    fn drawCrosshair() void {
        const crosshair_size = 10;
        const screen_width = raylib.GetScreenWidth();
        const screen_height = raylib.GetScreenHeight();
        const screen_center_x = @divTrunc(screen_width, 2);
        const screen_center_y = @divTrunc(screen_height, 2);
        raylib.DrawLine(screen_center_x, screen_center_y + crosshair_size, screen_center_x, screen_center_y - crosshair_size, raylib.WHITE);
        raylib.DrawLine(screen_center_x + crosshair_size, screen_center_y, screen_center_x - crosshair_size, screen_center_y, raylib.WHITE);

        // TODO: Should we visualize yaw and pitch changes with a circle?
        // const mouse_position = raylib.GetMousePosition();
        // raylib.DrawCircleLinesV(mouse_position, 10, raylib.WHITE);
    }
};
