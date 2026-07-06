import unittest

import flowworkrunner

suite "metrics":
  test "summarizes batch execution shape":
    var graph = initWorkGraph("pipeline")
    graph.nodes.add(workNode("extract"))
    graph.nodes.add(workNode("a"))
    graph.nodes.add(workNode("b"))
    graph.nodes.add(workNode("publish"))
    graph.edges.add(workEdge("extract-a", "extract", "a"))
    graph.edges.add(workEdge("extract-b", "extract", "b"))
    graph.edges.add(workEdge("a-publish", "a", "publish"))
    graph.edges.add(workEdge("b-publish", "b", "publish"))

    var executors = initWorkExecutorRegistry()
    executors.register("extract", proc(node: WorkNode): WorkTaskResult =
      succeeded(node.id, 10))
    executors.register("a", proc(node: WorkNode): WorkTaskResult =
      succeeded(node.id, 40))
    executors.register("b", proc(node: WorkNode): WorkTaskResult =
      succeeded(node.id, 30))
    executors.register("publish", proc(node: WorkNode): WorkTaskResult =
      succeeded(node.id, 5))

    let outcome = initWorkRunInput(graph, executors).run()
    let metrics = outcome.report.workRunMetrics()
    check metrics.batchCount == 3
    check metrics.maxBatchWidth == 2
    check metrics.taskCount == 4
    check metrics.succeededCount == 4
    check metrics.totalTaskDurationMillis == 85
    check metrics.estimatedElapsedMillis == 55
    check metrics.parallelismFactor > 1.5
    check metrics.successRate == 100.0
