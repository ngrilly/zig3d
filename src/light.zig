//! Based on raylib.lights

const std = @import("std");
const raylib = @import("raylib.zig");

/// Max dynamic lights supported by shader
pub const MAX_LIGHTS = 4;

pub const Light = struct {
    type: LightType,
    enabled: bool,
    position: raylib.Vector3,
    target: raylib.Vector3,
    color: raylib.Color,

    // Shader locations
    enabled_loc: c_int,
    type_loc: c_int,
    position_loc: c_int,
    target_loc: c_int,
    color_loc: c_int,
};

pub const LightType = enum(c_int) {
    LIGHT_DIRECTIONAL,
    LIGHT_POINT,
};

/// Current amount of created lights
var lights_count: u32 = 0;

/// Create a light and get shader locations
pub fn CreateLight(light_type: LightType, position: raylib.Vector3, target: raylib.Vector3, color: raylib.Color, shader: raylib.Shader) Light {
    if (lights_count >= MAX_LIGHTS)
        std.debug.panic("Error creating light: too many lights", .{});

    const light = Light{
        .enabled = true,
        .type = light_type,
        .position = position,
        .target = target,
        .color = color,

        // NOTE: Lighting shader naming must be the provided ones
        .enabled_loc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].enabled", lights_count)),
        .type_loc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].type", lights_count)),
        .position_loc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].position", lights_count)),
        .target_loc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].target", lights_count)),
        .color_loc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].color", lights_count)),
    };

    UpdateLightValues(shader, light);

    lights_count += 1;

    return light;
}

/// Send light properties to shader
/// NOTE: Light shader locations should be available
pub fn UpdateLightValues(shader: raylib.Shader, light: Light) void {
    // Send to shader light enabled state and type
    const enabled: c_int = @intFromBool(light.enabled);
    raylib.SetShaderValue(shader, light.enabled_loc, &enabled, raylib.SHADER_UNIFORM_INT);
    raylib.SetShaderValue(shader, light.type_loc, &@intFromEnum(light.type), raylib.SHADER_UNIFORM_INT);

    // Send to shader light position values
    const position = [_]f32{ light.position.x, light.position.y, light.position.z };
    raylib.SetShaderValue(shader, light.position_loc, &position, raylib.SHADER_UNIFORM_VEC3);

    // Send to shader light target position values
    const target = [_]f32{ light.target.x, light.target.y, light.target.z };
    raylib.SetShaderValue(shader, light.target_loc, &target, raylib.SHADER_UNIFORM_VEC3);

    // Send to shader light color values
    const color = [_]f32{
        @as(f32, @floatFromInt(light.color.r)) / 255,
        @as(f32, @floatFromInt(light.color.g)) / 255,
        @as(f32, @floatFromInt(light.color.b)) / 255,
        @as(f32, @floatFromInt(light.color.a)) / 255,
    };
    raylib.SetShaderValue(shader, light.color_loc, &color, raylib.SHADER_UNIFORM_VEC4);
}
