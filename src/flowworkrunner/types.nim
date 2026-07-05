const
  ReportSchemaVersion* = 1

type
  WorkStatus* = enum
    wsPending,
    wsRunning,
    wsSucceeded,
    wsFailed,
    wsSkipped

  WorkEventKind* = enum
    wekRunStarted,
    wekRunFinished,
    wekTaskStarted,
    wekTaskFinished,
    wekTaskSkipped,
    wekNote

  KeyValue* = object
    key*: string
    value*: string

  WorkNode* = object
    id*: string
    label*: string
    variantId*: string
    metadata*: seq[KeyValue]

  WorkEdge* = object
    id*: string
    fromNode*: string
    toNode*: string
    waitOn*: bool
    metadata*: seq[KeyValue]

  WorkGraph* = object
    id*: string
    variantId*: string
    nodes*: seq[WorkNode]
    edges*: seq[WorkEdge]

  ReadyBatch* = object
    index*: Natural
    nodeIds*: seq[string]

  WorkTaskResult* = object
    nodeId*: string
    status*: WorkStatus
    durationMillis*: Natural
    message*: string
    metrics*: seq[KeyValue]

  WorkEvent* = object
    id*: string
    flowId*: string
    runId*: string
    variantId*: string
    nodeId*: string
    edgeId*: string
    kind*: WorkEventKind
    status*: WorkStatus
    durationMillis*: Natural
    message*: string
    metrics*: seq[KeyValue]

  WorkRunOptions* = object
    runId*: string
    failFast*: bool
    maxBatchSize*: Natural

  WorkRunReport* = object
    schemaVersion*: Natural
    flowId*: string
    runId*: string
    variantId*: string
    status*: WorkStatus
    batches*: seq[ReadyBatch]
    results*: seq[WorkTaskResult]
    events*: seq[WorkEvent]
    errors*: seq[string]

proc kv*(key, value: string): KeyValue =
  KeyValue(key: key, value: value)

proc workNode*(id: string; label = ""; variantId = "";
    metadata: openArray[KeyValue] = []): WorkNode =
  WorkNode(id: id, label: label, variantId: variantId, metadata: @metadata)

proc workEdge*(id, fromNode, toNode: string; waitOn = true;
    metadata: openArray[KeyValue] = []): WorkEdge =
  WorkEdge(
    id: id,
    fromNode: fromNode,
    toNode: toNode,
    waitOn: waitOn,
    metadata: @metadata
  )

proc initWorkGraph*(id: string; variantId = ""): WorkGraph =
  WorkGraph(id: id, variantId: variantId)

proc defaultWorkRunOptions*(runId = "run"; failFast = false;
    maxBatchSize: Natural = 0): WorkRunOptions =
  WorkRunOptions(runId: runId, failFast: failFast, maxBatchSize: maxBatchSize)

proc succeeded*(nodeId: string; durationMillis: Natural = 0; message = "";
    metrics: openArray[KeyValue] = []): WorkTaskResult =
  WorkTaskResult(
    nodeId: nodeId,
    status: wsSucceeded,
    durationMillis: durationMillis,
    message: message,
    metrics: @metrics
  )

proc failed*(nodeId: string; durationMillis: Natural = 0; message = "";
    metrics: openArray[KeyValue] = []): WorkTaskResult =
  WorkTaskResult(
    nodeId: nodeId,
    status: wsFailed,
    durationMillis: durationMillis,
    message: message,
    metrics: @metrics
  )

proc skipped*(nodeId: string; message = "";
    metrics: openArray[KeyValue] = []): WorkTaskResult =
  WorkTaskResult(
    nodeId: nodeId,
    status: wsSkipped,
    message: message,
    metrics: @metrics
  )
