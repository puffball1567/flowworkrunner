import std/algorithm
import std/tables

import ./types
import ./validation

proc incomingEdges*(graph: WorkGraph; nodeId: string): seq[WorkEdge] =
  for edge in graph.edges:
    if edge.toNode == nodeId:
      result.add(edge)

proc outgoingEdges*(graph: WorkGraph; nodeId: string): seq[WorkEdge] =
  for edge in graph.edges:
    if edge.fromNode == nodeId:
      result.add(edge)

proc topologicalOrder*(graph: WorkGraph): seq[string] =
  requireValid(graph)
  var indegree = initTable[string, int]()
  var outgoing = initTable[string, seq[string]]()

  for node in graph.nodes:
    indegree[node.id] = 0
    outgoing[node.id] = @[]

  for edge in graph.edges:
    indegree[edge.toNode] = indegree.getOrDefault(edge.toNode) + 1
    outgoing[edge.fromNode].add(edge.toNode)

  var ready: seq[string]
  for node in graph.nodes:
    if indegree[node.id] == 0:
      ready.add(node.id)
  ready.sort()

  while ready.len > 0:
    let nodeId = ready[0]
    ready.delete(0)
    result.add(nodeId)

    var children = outgoing[nodeId]
    children.sort()
    for child in children:
      indegree[child] = indegree[child] - 1
      if indegree[child] == 0:
        ready.add(child)
    ready.sort()

  if result.len != graph.nodes.len:
    raise newException(ValueError, "cycle detected")

proc readyBatches*(graph: WorkGraph; maxBatchSize: Natural = 0): seq[ReadyBatch] =
  requireValid(graph)
  discard graph.topologicalOrder()

  var indegree = initTable[string, int]()
  var outgoing = initTable[string, seq[string]]()
  for node in graph.nodes:
    indegree[node.id] = 0
    outgoing[node.id] = @[]
  for edge in graph.edges:
    indegree[edge.toNode] = indegree.getOrDefault(edge.toNode) + 1
    outgoing[edge.fromNode].add(edge.toNode)

  var ready: seq[string]
  for node in graph.nodes:
    if indegree[node.id] == 0:
      ready.add(node.id)
  ready.sort()

  var index: Natural = 0
  while ready.len > 0:
    var current = ready
    if maxBatchSize > 0 and current.len > int(maxBatchSize):
      current.setLen(int(maxBatchSize))

    for _ in 0 ..< current.len:
      ready.delete(0)
    result.add(ReadyBatch(index: index, nodeIds: current))
    inc index

    var newlyReady: seq[string]
    for nodeId in current:
      var children = outgoing[nodeId]
      children.sort()
      for child in children:
        indegree[child] = indegree[child] - 1
        if indegree[child] == 0:
          newlyReady.add(child)
    ready.add(newlyReady)
    ready.sort()
