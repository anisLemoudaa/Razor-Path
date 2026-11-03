#!/usr/bin/env python3

# godot-cpp owns platform, architecture, API generation and compiler flags.
env = SConscript("godot-cpp/SConstruct")
env.Append(CPPPATH=["native/src"])
sources = Glob("native/src/*.cpp")
variant = "{}.{}.{}".format(env["platform"], env["target"], env["arch"])

library = env.SharedLibrary(
	target="native/bin/librazor_path." + variant + ".so",
    source=sources,
)
Default(library)
