import std/json

import ./types

proc toJson*(value: KeyValue): JsonNode =
  %*{"key": value.key, "value": value.value}

proc toJson*(value: ReadyBatch): JsonNode =
  result = newJObject()
  result["index"] = %int(value.index)
  result["nodeIds"] = newJArray()
  for item in value.nodeIds:
    result["nodeIds"].add(%item)

proc toJson*(value: WorkTaskResult): JsonNode =
  result = %*{
    "nodeId": value.nodeId,
    "status": $value.status,
    "durationMillis": int(value.durationMillis),
    "message": value.message
  }
  result["metrics"] = newJArray()
  for item in value.metrics:
    result["metrics"].add(toJson(item))

proc toJson*(value: WorkEvent): JsonNode =
  result = %*{
    "id": value.id,
    "flowId": value.flowId,
    "runId": value.runId,
    "variantId": value.variantId,
    "nodeId": value.nodeId,
    "edgeId": value.edgeId,
    "kind": $value.kind,
    "status": $value.status,
    "durationMillis": int(value.durationMillis),
    "message": value.message
  }
  result["metrics"] = newJArray()
  for item in value.metrics:
    result["metrics"].add(toJson(item))

proc toJson*(value: WorkRunReport): JsonNode =
  result = newJObject()
  result["schemaVersion"] = %int(value.schemaVersion)
  result["flowId"] = %value.flowId
  result["runId"] = %value.runId
  result["variantId"] = %value.variantId
  result["status"] = %($value.status)
  result["batches"] = newJArray()
  for item in value.batches:
    result["batches"].add(toJson(item))
  result["results"] = newJArray()
  for item in value.results:
    result["results"].add(toJson(item))
  result["events"] = newJArray()
  for item in value.events:
    result["events"].add(toJson(item))
  result["errors"] = newJArray()
  for item in value.errors:
    result["errors"].add(%item)

proc toJsonString*(value: WorkRunReport): string =
  $toJson(value)
