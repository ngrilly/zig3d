//! Based on raylib.lights

const std = @import("std");
const raylib = @import("raylib.zig").c;

/// Max dynamic lights supported by shader
pub const MAX_LIGHTS = 4;

pub const Light = struct {
    type: LightType,
    enabled: bool,
    position: raylib.Vector3,
    target: raylib.Vector3,
    color: raylib.Color,

    // Shader locations
    enabledLoc: c_int,
    typeLoc: c_int,
    positionLoc: c_int,
    targetLoc: c_int,
    colorLoc: c_int,
};

pub const LightType = enum(c_int) {
    LIGHT_DIRECTIONAL,
    LIGHT_POINT,
};

/// Current amount of created lights
var lightsCount: u32 = 0;

/// Create a light and get shader locations
pub fn CreateLight(lightType: LightType, position: raylib.Vector3, target: raylib.Vector3, color: raylib.Color, shader: raylib.Shader) Light {
    if (lightsCount >= MAX_LIGHTS)
        std.debug.panic("Error creating light: too many lights", .{});

    const light = Light{
        .enabled = true,
        .type = lightType,
        .position = position,
        .target = target,
        .color = color,

        // NOTE: Lighting shader naming must be the provided ones
        .enabledLoc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].enabled", lightsCount)),
        .typeLoc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].type", lightsCount)),
        .positionLoc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].position", lightsCount)),
        .targetLoc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].target", lightsCount)),
        .colorLoc = raylib.GetShaderLocation(shader, raylib.TextFormat("lights[%i].color", lightsCount)),
    };

    UpdateLightValues(shader, light);

    lightsCount += 1;

    return light;
}

/// Send light properties to shader
/// NOTE: Light shader locations should be available
pub fn UpdateLightValues(shader: raylib.Shader, light: Light) void {
    // Send to shader light enabled state and type
    const enabled: c_int = @intFromBool(light.enabled);
    raylib.SetShaderValue(shader, light.enabledLoc, &enabled, raylib.SHADER_UNIFORM_INT);
    raylib.SetShaderValue(shader, light.typeLoc, &@intFromEnum(light.type), raylib.SHADER_UNIFORM_INT);

    // Send to shader light position values
    const position = [_]f32{ light.position.x, light.position.y, light.position.z };
    raylib.SetShaderValue(shader, light.positionLoc, &position, raylib.SHADER_UNIFORM_VEC3);

    // Send to shader light target position values
    const target = [_]f32{ light.target.x, light.target.y, light.target.z };
    raylib.SetShaderValue(shader, light.targetLoc, &target, raylib.SHADER_UNIFORM_VEC3);

    // Send to shader light color values
    const color = [_]f32{
        @as(f32, @floatFromInt(light.color.r)) / 255,
        @as(f32, @floatFromInt(light.color.g)) / 255,
        @as(f32, @floatFromInt(light.color.b)) / 255,
        @as(f32, @floatFromInt(light.color.a)) / 255,
    };
    raylib.SetShaderValue(shader, light.colorLoc, &color, raylib.SHADER_UNIFORM_VEC4);
}
