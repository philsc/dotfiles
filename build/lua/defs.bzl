"""Runs Lua scripts as Bazel tests with the interpreter from @lua."""

def _lua_test_impl(ctx):
    lua = ctx.executable._lua

    # Tests run with the runfiles root of the main repository as the working
    # directory, so the short paths of the source files resolve as is. require()
    # searches the directories of the test and its deps.
    dirs = {}
    for f in [ctx.file.src] + ctx.files.deps:
        dirs[f.dirname] = True
    lua_path = ";".join([d + "/?.lua" for d in dirs.keys()])

    launcher = ctx.actions.declare_file(ctx.label.name + ".sh")
    ctx.actions.write(
        output = launcher,
        content = """#!/bin/sh
export LUA_PATH="{lua_path};;"
exec "{lua}" "{src}" "$@"
""".format(
            lua_path = lua_path,
            lua = lua.short_path,
            src = ctx.file.src.short_path,
        ),
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [lua, ctx.file.src] + ctx.files.deps + ctx.files.data)
    runfiles = runfiles.merge(ctx.attr._lua[DefaultInfo].default_runfiles)
    return [DefaultInfo(executable = launcher, runfiles = runfiles)]

lua_test = rule(
    implementation = _lua_test_impl,
    test = True,
    attrs = {
        "src": attr.label(
            doc = "The test script.",
            allow_single_file = [".lua"],
            mandatory = True,
        ),
        "deps": attr.label_list(
            doc = "Lua files the test require()s.",
            allow_files = [".lua"],
        ),
        "data": attr.label_list(
            doc = "Other files the test needs at runtime.",
            allow_files = True,
        ),
        "_lua": attr.label(
            default = "@lua//:bin/lua",
            executable = True,
            cfg = "exec",
        ),
    },
)
