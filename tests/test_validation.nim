import std/unittest

import flowworkrunner

suite "validation":
  test "accepts a valid graph":
    var graph = initWorkGraph("flow")
    graph.nodes.add(workNode("a"))
    graph.nodes.add(workNode("b"))
    graph.edges.add(workEdge("a-b", "a", "b"))

    check validate(graph).ok

  test "rejects invalid graph references":
    var graph = initWorkGraph("")
    graph.nodes.add(workNode("a"))
    graph.nodes.add(workNode("a"))
    graph.edges.add(workEdge("bad", "a", "missing"))

    let result = validate(graph)
    check not result.ok
    check result.errors.len >= 3

  test "rejects empty graphs":
    let result = validate(initWorkGraph("flow"))

    check not result.ok
    check result.errors == @["graph requires at least one node"]
