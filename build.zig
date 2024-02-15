const std = @import("std");

pub const GenerateRoutes = @import("src/GenerateRoutes.zig");
pub const TemplateFn = @import("src/jetzig.zig").TemplateFn;
pub const StaticRequest = @import("src/jetzig.zig").StaticRequest;
pub const http = @import("src/jetzig/http.zig");
pub const data = @import("src/jetzig/data.zig");
pub const views = @import("src/jetzig/views.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const template_path = b.option([]const u8, "zmpl_templates_path", "Path to templates") orelse "src/app/views/";
    const manifest: []const u8 = b.pathJoin(&.{ template_path, "zmpl.manifest.zig" });

    const lib = b.addStaticLibrary(.{
        .name = "jetzig",
        .root_source_file = .{ .path = "src/jetzig.zig" },
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(lib);

    const jetzig_module = b.addModule("jetzig", .{ .root_source_file = .{ .path = "src/jetzig.zig" } });
    lib.root_module.addImport("jetzig", jetzig_module);

    const zmpl_dep = b.dependency(
        "zmpl",
        .{
            .target = target,
            .optimize = optimize,
            .zmpl_templates_path = template_path,
            .zmpl_manifest_path = manifest,
        },
    );

    lib.root_module.addImport("zmpl", zmpl_dep.module("zmpl"));
    jetzig_module.addImport("zmpl", zmpl_dep.module("zmpl"));

    // This is the way to make it look nice in the zig build script
    // If we would do it the other way around, we would have to do
    // b.dependency("jetzig",.{}).builder.dependency("zmpl",.{}).module("zmpl");
    b.modules.put("zmpl", zmpl_dep.module("zmpl")) catch @panic("Out of memory");

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
    });

    const docs_step = b.step("docs", "Generate documentation");
    const docs_install = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    docs_step.dependOn(&docs_install.step);

    main_tests.root_module.addImport("zmpl", zmpl_dep.module("zmpl"));
    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);
}
