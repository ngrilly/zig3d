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

# TODO

- How to get autocompletion on raylib?