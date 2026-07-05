import std/unittest

import flowworkrunner

proc graphWithFailurePath(waitOn: bool): WorkGraph =
  result = initWorkGraph("flow")
  result.nodes.add(workNode("a"))
  result.nodes.add(workNode("b"))
  result.edges.add(workEdge("a-b", "a", "b", waitOn = waitOn))

suite "executor":
  test "runs registered executors in dependency order":
    var graph = initWorkGraph("flow")
    graph.nodes.add(workNode("a"))
    graph.nodes.add(workNode("b"))
    graph.edges.add(workEdge("a-b", "a", "b"))

    var calls: seq[string]
    var executors = initWorkExecutorRegistry()
    executors.register("a", proc(node: WorkNode): WorkTaskResult =
      calls.add(node.id)
      succeeded(node.id, durationMillis = 10)
    )
    executors.register("b", proc(node: WorkNode): WorkTaskResult =
      calls.add(node.id)
      succeeded(node.id, durationMillis = 5)
    )

    let outcome = run(initWorkRunInput(graph, executors))

    check outcome.ok
    check calls == @["a", "b"]
    check outcome.report.schemaVersion == ReportSchemaVersion
    check outcome.report.status == wsSucceeded
    check outcome.report.results.len == 2

  test "returns missing executor errors as data":
    var graph = initWorkGraph("flow")
    graph.nodes.add(workNode("a"))
    let outcome = run(initWorkRunInput(graph, initWorkExecutorRegistry()))

    check not outcome.ok
    check outcome.errors == @["executor missing for node: a"]
    check outcome.report.status == wsFailed

  test "skips wait-on dependents when required source fails":
    var executors = initWorkExecutorRegistry()
    executors.register("a", proc(node: WorkNode): WorkTaskResult =
      failed(node.id, message = "boom")
    )
    executors.register("b", proc(node: WorkNode): WorkTaskResult =
      succeeded(node.id)
    )

    let outcome = run(initWorkRunInput(graphWithFailurePath(waitOn = true), executors))

    check not outcome.ok
    check outcome.report.results.len == 2
    check outcome.report.results[0].status == wsFailed
    check outcome.report.results[1].status == wsSkipped

  test "allows non-wait-on dependents after source failure":
    var executors = initWorkExecutorRegistry()
    executors.register("a", proc(node: WorkNode): WorkTaskResult =
      failed(node.id, message = "boom")
    )
    executors.register("b", proc(node: WorkNode): WorkTaskResult =
      succeeded(node.id)
    )

    let outcome = run(initWorkRunInput(graphWithFailurePath(waitOn = false), executors))

    check not outcome.ok
    check outcome.report.results.len == 2
    check outcome.report.results[0].status == wsFailed
    check outcome.report.results[1].status == wsSucceeded

  test "converts executor exceptions into failed task results":
    var graph = initWorkGraph("flow")
    graph.nodes.add(workNode("a"))
    var executors = initWorkExecutorRegistry()
    executors.register("a", proc(node: WorkNode): WorkTaskResult =
      raise newException(ValueError, "bad task")
    )

    let outcome = run(initWorkRunInput(graph, executors))

    check not outcome.ok
    check outcome.report.results[0].status == wsFailed
    check outcome.report.results[0].message == "bad task"

  test "rejects non-terminal executor statuses":
    var graph = initWorkGraph("flow")
    graph.nodes.add(workNode("a"))
    var executors = initWorkExecutorRegistry()
    executors.register("a", proc(node: WorkNode): WorkTaskResult =
      WorkTaskResult(nodeId: node.id, status: wsRunning)
    )

    let outcome = run(initWorkRunInput(graph, executors))

    check not outcome.ok
    check outcome.report.results[0].status == wsFailed
    check outcome.report.results[0].message == "executor returned non-terminal status: wsRunning"

  test "fail fast stops later batches after failure":
    var graph = initWorkGraph("flow")
    graph.nodes.add(workNode("a"))
    graph.nodes.add(workNode("b"))
    graph.edges.add(workEdge("a-b", "a", "b", waitOn = false))
    var executors = initWorkExecutorRegistry()
    executors.register("a", proc(node: WorkNode): WorkTaskResult =
      failed(node.id)
    )
    executors.register("b", proc(node: WorkNode): WorkTaskResult =
      succeeded(node.id)
    )

    let outcome = run(initWorkRunInput(
      graph,
      executors,
      options = defaultWorkRunOptions(failFast = true)
    ))

    check not outcome.ok
    check outcome.report.results.len == 1
    check outcome.report.results[0].nodeId == "a"
