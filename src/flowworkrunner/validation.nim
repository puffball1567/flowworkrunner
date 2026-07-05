import std/sets
import std/strutils

import ./types

type
  ValidationResult* = object
    ok*: bool
    errors*: seq[string]

proc valid*(): ValidationResult =
  ValidationResult(ok: true)

proc invalid*(errors: seq[string]): ValidationResult =
  ValidationResult(ok: false, errors: errors)

proc validate*(graph: WorkGraph): ValidationResult =
  var errors: seq[string]
  if graph.id.strip().len == 0:
    errors.add("graph id is required")
  if graph.nodes.len == 0:
    errors.add("graph requires at least one node")

  var nodeIds = initHashSet[string]()
  for node in graph.nodes:
    let nodeId = node.id.strip()
    if nodeId.len == 0:
      errors.add("node id is required")
    elif nodeId in nodeIds:
      errors.add("duplicate node id: " & nodeId)
    else:
      nodeIds.incl(nodeId)

  var edgeIds = initHashSet[string]()
  for edge in graph.edges:
    let edgeId = edge.id.strip()
    if edgeId.len == 0:
      errors.add("edge id is required")
    elif edgeId in edgeIds:
      errors.add("duplicate edge id: " & edgeId)
    else:
      edgeIds.incl(edgeId)

    if edge.fromNode.strip().len == 0:
      errors.add("edge fromNode is required")
    elif edge.fromNode notin nodeIds:
      errors.add("edge references missing fromNode: " & edge.fromNode)

    if edge.toNode.strip().len == 0:
      errors.add("edge toNode is required")
    elif edge.toNode notin nodeIds:
      errors.add("edge references missing toNode: " & edge.toNode)

    if edge.fromNode == edge.toNode and edge.fromNode.strip().len > 0:
      errors.add("edge must not point to the same node: " & edge.id)

  if errors.len == 0:
    return valid()
  invalid(errors)

proc requireValid*(graph: WorkGraph) =
  let result = validate(graph)
  if not result.ok:
    raise newException(ValueError, result.errors.join("; "))
