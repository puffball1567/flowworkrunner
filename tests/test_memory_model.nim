import std/unittest
import flowworkrunner

suite "memory model":
  test "uses Nim ARC memory manager":
    when defined(gcArc):
      check true
    else:
      check false

  test "creates and releases work graphs and reports under ARC":
    var totalEvents = 0
    for i in 0 ..< 200:
      var graph = initWorkGraph("work-" & $i, variantId = "A")
      graph.nodes.add workNode("prepare-" & $i, metadata = [kv("queue", "default")])
      graph.nodes.add workNode("finish-" & $i, metadata = [kv("queue", "default")])
      graph.edges.add workEdge("edge-" & $i, graph.nodes[0].id, graph.nodes[1].id)
      let report = WorkRunReport(
        schemaVersion: ReportSchemaVersion,
        flowId: graph.id,
        runId: "run-" & $i,
        variantId: graph.variantId,
        status: wsSucceeded,
        batches: @[ReadyBatch(index: 0, nodeIds: @[graph.nodes[0].id, graph.nodes[1].id])],
        results: @[succeeded(graph.nodes[0].id), succeeded(graph.nodes[1].id)],
        events: @[WorkEvent(kind: wekRunStarted), WorkEvent(kind: wekRunFinished)],
        errors: @[]
      )
      totalEvents += report.events.len
    check totalEvents == 400
