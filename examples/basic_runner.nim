import flowworkrunner

var graph = initWorkGraph("daily-report")
graph.nodes.add(workNode("extract"))
graph.nodes.add(workNode("publish"))
graph.edges.add(workEdge("extract-publish", "extract", "publish", waitOn = true))

var executors = initWorkExecutorRegistry()
executors.register("extract", proc(node: WorkNode): WorkTaskResult =
  succeeded(node.id, durationMillis = 10, message = "loaded input")
)
executors.register("publish", proc(node: WorkNode): WorkTaskResult =
  succeeded(node.id, durationMillis = 5, message = "published report")
)

let outcome = run(initWorkRunInput(graph, executors))
if outcome.ok:
  echo outcome.report.toJsonString()
else:
  echo outcome.errors
