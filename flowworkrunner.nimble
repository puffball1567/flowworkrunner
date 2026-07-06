version       = "0.2.0"
author        = "flowworkrunner contributors"
description   = "In-process work runner primitives for FlowBrigade Toolkit graphs."
license       = "Apache-2.0"
srcDir        = "src"
installExt    = @["nim"]
skipDirs      = @[
  ".github",
  "benchmarks",
  "docs",
  "examples",
  "tests"
]

requires "nim >= 2.2.0"

task test, "Run the test suite":
  exec "nim r --nimcache:/tmp/flowworkrunner-test-nimcache -p:src tests/all.nim"

task examples, "Check examples":
  exec "nim check --nimcache:/tmp/flowworkrunner-nimcache -p:src examples/basic_runner.nim"

task bench, "Run basic local benchmarks":
  exec "nim r -d:release --nimcache:/tmp/flowworkrunner-bench-nimcache -p:src benchmarks/basic_runner.nim"
