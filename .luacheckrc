std = "luajit"
globals = {"vim", "describe", "it", "setup", "teardown", "before_each", "after_each", "spy", "stub", "mock"}

files["tests/"] = {
  std = "luajit+busted",
  read_globals = { "assert" }
}

exclude_files = {
  "tests/minimal_init.lua"
}
