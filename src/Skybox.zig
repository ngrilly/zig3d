//! Skybox, based on https://github.com/raysan5/raylib/blob/master/examples/models/models_skybox.c.
//!
//! Further reading:
//! - https://scaryreasoner.wordpress.com/2013/09/10/opengl-skybox-in-space-nerds-in-space/
//! - https://ogldev.org/www/tutorial25/tutorial25.html
//!

const Skybox = @This();

const raylib = @import("raylib.zig");

skybox: raylib.Model,

pub fn init() Skybox {
    const cube = raylib.GenMeshCube(1.0, 1.0, 1.0);
    const skybox = raylib.LoadModelFromMesh(cube);

    skybox.materials[0].shader = raylib.LoadShaderFromMemory(@embedFile("shaders/glsl330/skybox.vs"), @embedFile("shaders/glsl330/skybox.fs"));

    raylib.SetShaderValue(skybox.materials[0].shader, raylib.GetShaderLocation(skybox.materials[0].shader, "environmentMap"), &raylib.MATERIAL_MAP_CUBEMAP, raylib.SHADER_UNIFORM_INT);
    raylib.SetShaderValue(skybox.materials[0].shader, raylib.GetShaderLocation(skybox.materials[0].shader, "doGamma"), &[1]c_int{0}, raylib.SHADER_UNIFORM_INT);
    raylib.SetShaderValue(skybox.materials[0].shader, raylib.GetShaderLocation(skybox.materials[0].shader, "vflipped"), &[1]c_int{0}, raylib.SHADER_UNIFORM_INT);

    const img = raylib.LoadImage("resources/space-skybox-texture-mapping-cube-mapping-night-sky-24df7747449631f3f2a45fc630ae6ad0.png");
    skybox.materials[0].maps[raylib.MATERIAL_MAP_CUBEMAP].texture = raylib.LoadTextureCubemap(img, raylib.CUBEMAP_LAYOUT_AUTO_DETECT);
    raylib.UnloadImage(img);

    return .{
        .skybox = skybox,
    };
}

// TODO: Should we use Skybox or *Skybox instead of *const Skybox?
pub fn deinit(self: *const Skybox) void {
    raylib.UnloadTexture(self.skybox.materials[0].maps[raylib.MATERIAL_MAP_CUBEMAP].texture);
    raylib.UnloadShader(self.skybox.materials[0].shader);
    raylib.UnloadModel(self.skybox);
}

pub fn draw(self: *const Skybox) void {
    // We are inside the cube, we need to disable backface culling!
    raylib.rlDisableBackfaceCulling();
    raylib.rlDisableDepthMask();
    raylib.DrawModel(self.skybox, raylib.Vector3{ .x = 0, .y = 0, .z = 0 }, 1.0, raylib.WHITE);
    raylib.rlEnableDepthMask();
    raylib.rlEnableBackfaceCulling();
}
