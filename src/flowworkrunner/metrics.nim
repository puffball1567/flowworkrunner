import std/tables

import ./types

type
  WorkRunMetrics* = object
    batchCount*: Natural
    maxBatchWidth*: Natural
    averageBatchWidth*: float
    taskCount*: Natural
    succeededCount*: Natural
    failedCount*: Natural
    skippedCount*: Natural
    totalTaskDurationMillis*: Natural
    estimatedElapsedMillis*: Natural
    parallelismFactor*: float
    successRate*: float

proc workRunMetrics*(report: WorkRunReport): WorkRunMetrics =
  result.batchCount = Natural(report.batches.len)
  result.taskCount = Natural(report.results.len)

  var resultByNode = initTable[string, WorkTaskResult]()
  for item in report.results:
    resultByNode[item.nodeId] = item
    result.totalTaskDurationMillis.inc item.durationMillis
    case item.status
    of wsSucceeded:
      result.succeededCount.inc
    of wsFailed:
      result.failedCount.inc
    of wsSkipped:
      result.skippedCount.inc
    else:
      discard

  var batchWidthTotal = 0
  for batch in report.batches:
    result.maxBatchWidth = max(result.maxBatchWidth, Natural(batch.nodeIds.len))
    batchWidthTotal.inc batch.nodeIds.len
    var batchDuration: Natural = 0
    for nodeId in batch.nodeIds:
      if resultByNode.hasKey(nodeId):
        batchDuration = max(batchDuration, resultByNode[nodeId].durationMillis)
    result.estimatedElapsedMillis.inc batchDuration

  if report.batches.len > 0:
    result.averageBatchWidth = batchWidthTotal.float / report.batches.len.float
  if result.estimatedElapsedMillis > 0:
    result.parallelismFactor =
      result.totalTaskDurationMillis.float / result.estimatedElapsedMillis.float
  if report.results.len > 0:
    result.successRate =
      result.succeededCount.float / report.results.len.float * 100.0
