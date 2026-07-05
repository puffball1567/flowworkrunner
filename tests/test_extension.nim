import std/unittest

import flowworkrunner

proc singleNodeGraph(): WorkGraph =
  result = initWorkGraph("flow")
  result.nodes.add(workNode("a"))

proc succeedingExecutors(): WorkExecutorRegistry =
  result = initWorkExecutorRegistry()
  result.register("a", proc(node: WorkNode): WorkTaskResult =
    succeeded(node.id)
  )

suite "extension":
  test "validates plugin manifests":
    var extensions = initWorkExtensionRegistry()
    extensions.register(pluginManifest(
      "audit",
      "1.0.0",
      capabilities = [wpckEventSink, wpckTelemetry]
    ))

    check validate(extensions).ok
    check extensions.plugins[0].hasCapability(wpckEventSink)

  test "rejects invalid plugin manifests":
    var extensions = initWorkExtensionRegistry()
    extensions.register(pluginManifest("audit", "1.0.0"))
    extensions.register(pluginManifest("audit", ""))

    let result = validate(extensions)

    check not result.ok
    check result.errors.len == 2

  test "emits events to registered sinks":
    var seen: seq[WorkEventKind]
    var extensions = initWorkExtensionRegistry()
    extensions.addEventSink(proc(event: WorkEvent) =
      seen.add(event.kind)
    )

    let outcome = run(initWorkRunInput(
      singleNodeGraph(),
      succeedingExecutors(),
      extensions = extensions
    ))

    check outcome.ok
    check seen == @[wekRunStarted, wekTaskStarted, wekTaskFinished, wekRunFinished]

  test "records event sink failures without crashing the run":
    var extensions = initWorkExtensionRegistry()
    extensions.addEventSink(proc(event: WorkEvent) =
      raise newException(ValueError, "sink down")
    )

    let outcome = run(initWorkRunInput(
      singleNodeGraph(),
      succeedingExecutors(),
      extensions = extensions
    ))

    check outcome.ok
    check outcome.report.errors.len == 4
    check outcome.report.errors[0] == "event sink failed: sink down"

  test "task gates can skip a task":
    var extensions = initWorkExtensionRegistry()
    extensions.addTaskGate(proc(node: WorkNode): WorkTaskDecision =
      skipTask("disabled by plugin")
    )

    let outcome = run(initWorkRunInput(
      singleNodeGraph(),
      succeedingExecutors(),
      extensions = extensions
    ))

    check outcome.ok
    check outcome.report.results[0].status == wsSkipped
    check outcome.report.results[0].message == "disabled by plugin"

  test "task gates can fail a task":
    var extensions = initWorkExtensionRegistry()
    extensions.addTaskGate(proc(node: WorkNode): WorkTaskDecision =
      failTask("quota denied")
    )

    let outcome = run(initWorkRunInput(
      singleNodeGraph(),
      succeedingExecutors(),
      extensions = extensions
    ))

    check not outcome.ok
    check outcome.report.results[0].status == wsFailed
    check outcome.report.results[0].message == "quota denied"
