import std/unittest

import flowworkrunner

proc sampleGraph(): WorkGraph =
  result = initWorkGraph("flow")
  result.nodes.add(workNode("extract"))
  result.nodes.add(workNode("transform"))
  result.nodes.add(workNode("publish"))
  result.edges.add(workEdge("extract-transform", "extract", "transform"))
  result.edges.add(workEdge("transform-publish", "transform", "publish"))

suite "planner":
  test "computes topological order":
    check sampleGraph().topologicalOrder() == @["extract", "transform", "publish"]

  test "groups independent nodes into ready batches":
    var graph = initWorkGraph("flow")
    graph.nodes.add(workNode("a"))
    graph.nodes.add(workNode("b"))
    graph.nodes.add(workNode("c"))
    graph.edges.add(workEdge("a-c", "a", "c"))
    graph.edges.add(workEdge("b-c", "b", "c"))

    let batches = graph.readyBatches()
    check batches.len == 2
    check batches[0].nodeIds == @["a", "b"]
    check batches[1].nodeIds == @["c"]

  test "respects max batch size":
    var graph = initWorkGraph("flow")
    graph.nodes.add(workNode("a"))
    graph.nodes.add(workNode("b"))
    graph.nodes.add(workNode("c"))

    let batches = graph.readyBatches(maxBatchSize = 2)

    check batches.len == 2
    check batches[0].nodeIds == @["a", "b"]
    check batches[1].nodeIds == @["c"]

  test "rejects cycles":
    var graph = initWorkGraph("flow")
    graph.nodes.add(workNode("a"))
    graph.nodes.add(workNode("b"))
    graph.edges.add(workEdge("a-b", "a", "b"))
    graph.edges.add(workEdge("b-a", "b", "a"))

    expect ValueError:
      discard graph.topologicalOrder()
