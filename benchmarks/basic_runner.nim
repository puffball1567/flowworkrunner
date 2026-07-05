import std/monotimes
import std/strformat
import std/times

import flowworkrunner

const NodeCount = 5000

var graph = initWorkGraph("bench")
var executors = initWorkExecutorRegistry()
for index in 0 ..< NodeCount:
  let nodeId = "n" & $index
  graph.nodes.add(workNode(nodeId))
  executors.register(nodeId, proc(node: WorkNode): WorkTaskResult =
    succeeded(node.id)
  )
  if index > 0:
    graph.edges.add(workEdge("e" & $index, "n" & $(index - 1), nodeId))

let started = getMonoTime()
let outcome = run(initWorkRunInput(graph, executors))
let elapsed = getMonoTime() - started

if not outcome.ok:
  quit("benchmark run failed")

echo &"run: {NodeCount} nodes, {NodeCount - 1} edges in {elapsed.inMilliseconds} ms"
