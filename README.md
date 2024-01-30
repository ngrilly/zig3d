# Learnings

## How to use raylib?

- Add raylib as a dependency:
    ```
    zig fetch --save=raylib https://github.com/raysan5/raylib/archive/9d628d1d499f8ad9c0e6fbed69914cecb611d6cd.tar.gz
    ```
- Add the following in build.zig:
    ```
    const raylib_dep = b.dependency("raylib", .{});
    exe.linkLibrary(raylib_dep.artifact("raylib"));
    ```
- Import it in main.zig:
    ```
    const raylib = @cImport({
        @cInclude("raylib.h");
    });
    ```

How does the above compare to using an external Go module?

## Glossary

LOD: Level Of Detail
VBO: Vertex Buffer Object

## References

### Game physis

- https://www.youtube.com/watch?v=3lBYVSplAuo
- https://gafferongames.com/post/physics_in_3d/
- https://www.toptal.com/game/video-game-physics-part-i-an-introduction-to-rigid-body-dynamics
- https://gamemath.com/

# Problems

- How to transition from space to planet surface: https://gamedev.stackexchange.com/questions/108667/how-to-load-a-spherical-planet-and-its-regions
- Meshing in voxel engines:
    - https://0fps.net/2012/06/30/meshing-in-a-minecraft-game/
    - https://blackflux.wordpress.com/2014/02/23/meshing-in-voxel-engines-part-1/
    - https://nickmcd.me/2021/04/04/high-performance-voxel-engine/
    - [Approaching Zero Driver Overhead in OpenGL](https://gdcvault.com/play/1020791/)

# Todo

- Refactor the code
- Move resources to a dedicated directory
- Skybox
    - raylib has a skybox example
    - https://en.wikipedia.org/wiki/Cube_mapping
    - https://scaryreasoner.wordpress.com/2013/09/10/opengl-skybox-in-space-nerds-in-space/
    - https://ogldev.org/www/tutorial25/tutorial25.html
- Speed
- Sound (engine, collisions, etc.)
- Collisions

# Credits

- Engine sound: https://freesound.org/people/Nexotron/sounds/371282/