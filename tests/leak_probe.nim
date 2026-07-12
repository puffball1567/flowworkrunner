import flowworkrunner

proc main() =
  var totalResults = 0
  for i in 0 ..< 1000:
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
    discard validate(graph)
    discard readyBatches(graph)
    totalResults += report.results.len

  doAssert totalResults == 2000

main()
