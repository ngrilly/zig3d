//! Quaternion functions

const std = @import("std");
const raylib = @import("raylib.zig");

/// Rotates the given quaternion by the given angle, around the x-axis.
pub fn rotateX(q: raylib.Quaternion, angle: f32) raylib.Quaternion {
    const halfAngle = angle * 0.5;

    const qx = q.x;
    const qy = q.y;
    const qz = q.z;
    const qw = q.w;

    const bx = std.math.sin(halfAngle);
    const bw = std.math.cos(halfAngle);

    return raylib.Quaternion{
        .x = qx * bw + qw * bx,
        .y = qy * bw + qz * bx,
        .z = qz * bw - qy * bx,
        .w = qw * bw - qx * bx,
    };
}

/// Rotates the given quaternion by the given angle, around the y-axis.
pub fn rotateY(q: raylib.Quaternion, angle: f32) raylib.Quaternion {
    const halfAngle = angle * 0.5;

    const qx = q.x;
    const qy = q.y;
    const qz = q.z;
    const qw = q.w;

    const by = std.math.sin(halfAngle);
    const bw = std.math.cos(halfAngle);

    return raylib.Quaternion{
        .x = qx * bw - qz * by,
        .y = qy * bw + qw * by,
        .z = qz * bw + qx * by,
        .w = qw * bw - qy * by,
    };
}

/// Rotates the given quaternion by the given angle, around the z-axis.
pub fn rotateZ(q: raylib.Quaternion, angle: f32) raylib.Quaternion {
    const halfAngle = angle * 0.5;

    const qx = q.x;
    const qy = q.y;
    const qz = q.z;
    const qw = q.w;

    const bz = std.math.sin(halfAngle);
    const bw = std.math.cos(halfAngle);

    return raylib.Quaternion{
        .x = qx * bw - qy * bz,
        .y = qy * bw + qx * bz,
        .z = qz * bw + qw * bz,
        .w = qw * bw - qz * bz,
    };
}
