import std/tables

import ./extension
import ./planner
import ./types
import ./validation

type
  WorkExecutor* = proc(node: WorkNode): WorkTaskResult

  WorkExecutorRegistry* = object
    executors: Table[string, WorkExecutor]

  WorkRunInput* = object
    graph*: WorkGraph
    executors*: WorkExecutorRegistry
    options*: WorkRunOptions
    extensions*: WorkExtensionRegistry

  WorkRunOutcome* = object
    ok*: bool
    report*: WorkRunReport
    errors*: seq[string]

proc initWorkExecutorRegistry*(): WorkExecutorRegistry =
  WorkExecutorRegistry(executors: initTable[string, WorkExecutor]())

proc register*(registry: var WorkExecutorRegistry; nodeId: string;
    executor: WorkExecutor) =
  registry.executors[nodeId] = executor

proc hasExecutor*(registry: WorkExecutorRegistry; nodeId: string): bool =
  registry.executors.hasKey(nodeId)

proc initWorkRunInput*(graph: WorkGraph; executors: WorkExecutorRegistry;
    options = defaultWorkRunOptions();
    extensions = initWorkExtensionRegistry()): WorkRunInput =
  WorkRunInput(
    graph: graph,
    executors: executors,
    options: options,
    extensions: extensions
  )

proc eventId(runId, nodeId, suffix: string): string =
  runId & ":" & nodeId & ":" & suffix

proc workEvent*(id, flowId, runId: string; kind: WorkEventKind;
    variantId = ""; nodeId = ""; edgeId = ""; status = wsPending;
    durationMillis: Natural = 0; message = "";
    metrics: openArray[KeyValue] = []): WorkEvent =
  WorkEvent(
    id: id,
    flowId: flowId,
    runId: runId,
    variantId: variantId,
    nodeId: nodeId,
    edgeId: edgeId,
    kind: kind,
    status: status,
    durationMillis: durationMillis,
    message: message,
    metrics: @metrics
  )

proc validate*(input: WorkRunInput): ValidationResult =
  var errors: seq[string]
  let graphResult = validate(input.graph)
  if not graphResult.ok:
    for item in graphResult.errors:
      errors.add("graph: " & item)

  if input.options.runId.len == 0:
    errors.add("options: runId is required")

  if errors.len == 0:
    for node in input.graph.nodes:
      if not input.executors.hasExecutor(node.id):
        errors.add("executor missing for node: " & node.id)

  if errors.len == 0:
    try:
      discard input.graph.topologicalOrder()
    except ValueError as exc:
      errors.add("graph: " & exc.msg)

  let extensionResult = validate(input.extensions)
  if not extensionResult.ok:
    for item in extensionResult.errors:
      errors.add("extensions: " & item)

  if errors.len == 0:
    return valid()
  invalid(errors)

proc findNode(graph: WorkGraph; nodeId: string): WorkNode =
  for node in graph.nodes:
    if node.id == nodeId:
      return node
  raise newException(KeyError, "node not found: " & nodeId)

proc shouldSkip(graph: WorkGraph; nodeId: string;
    statuses: Table[string, WorkStatus]): string =
  for edge in graph.incomingEdges(nodeId):
    if edge.waitOn and statuses.getOrDefault(edge.fromNode, wsPending) in {wsFailed, wsSkipped}:
      return "required dependency did not succeed: " & edge.fromNode
  ""

proc normalizedResult(nodeId: string; taskResult: WorkTaskResult): WorkTaskResult =
  result = taskResult
  if result.nodeId.len == 0:
    result.nodeId = nodeId
  if result.nodeId != nodeId:
    return failed(nodeId, message = "executor returned result for a different node")
  if result.status in {wsPending, wsRunning}:
    return failed(nodeId, message = "executor returned non-terminal status: " & $result.status)

proc run*(input: WorkRunInput): WorkRunOutcome =
  let validation = validate(input)
  var report = WorkRunReport(
    schemaVersion: ReportSchemaVersion,
    flowId: input.graph.id,
    runId: input.options.runId,
    variantId: input.graph.variantId,
    status: wsRunning
  )

  if not validation.ok:
    report.status = wsFailed
    report.errors = validation.errors
    return WorkRunOutcome(ok: false, report: report, errors: validation.errors)

  proc addEvent(event: WorkEvent) =
    report.events.add(event)
    input.extensions.emit(event, report.errors)

  addEvent(workEvent(
    "run:" & input.options.runId & ":started",
    input.graph.id,
    input.options.runId,
    wekRunStarted,
    variantId = input.graph.variantId,
    status = wsRunning
  ))

  let batches = input.graph.readyBatches(input.options.maxBatchSize)
  report.batches = batches
  var statuses = initTable[string, WorkStatus]()
  var stopped = false

  for batch in batches:
    if stopped:
      break
    for nodeId in batch.nodeIds:
      let skipReason = input.graph.shouldSkip(nodeId, statuses)
      if skipReason.len > 0:
        let taskResult = skipped(nodeId, skipReason)
        statuses[nodeId] = wsSkipped
        report.results.add(taskResult)
        addEvent(workEvent(
          eventId(input.options.runId, nodeId, "skipped"),
          input.graph.id,
          input.options.runId,
          wekTaskSkipped,
          variantId = input.graph.variantId,
          nodeId = nodeId,
          status = wsSkipped,
          message = skipReason
        ))
        continue

      let gateDecision = input.extensions.evaluateTaskGates(input.graph.findNode(nodeId))
      if gateDecision.kind == wtdSkip:
        let reason =
          if gateDecision.reason.len == 0: "task skipped by extension gate"
          else: gateDecision.reason
        let taskResult = skipped(nodeId, reason)
        statuses[nodeId] = wsSkipped
        report.results.add(taskResult)
        addEvent(workEvent(
          eventId(input.options.runId, nodeId, "skipped"),
          input.graph.id,
          input.options.runId,
          wekTaskSkipped,
          variantId = input.graph.variantId,
          nodeId = nodeId,
          status = wsSkipped,
          message = reason
        ))
        continue
      elif gateDecision.kind == wtdFail:
        let reason =
          if gateDecision.reason.len == 0: "task failed by extension gate"
          else: gateDecision.reason
        let taskResult = failed(nodeId, message = reason)
        statuses[nodeId] = wsFailed
        report.results.add(taskResult)
        addEvent(workEvent(
          eventId(input.options.runId, nodeId, "finished"),
          input.graph.id,
          input.options.runId,
          wekTaskFinished,
          variantId = input.graph.variantId,
          nodeId = nodeId,
          status = wsFailed,
          message = reason
        ))
        if input.options.failFast:
          stopped = true
          break
        continue

      addEvent(workEvent(
        eventId(input.options.runId, nodeId, "started"),
        input.graph.id,
        input.options.runId,
        wekTaskStarted,
        variantId = input.graph.variantId,
        nodeId = nodeId,
        status = wsRunning
      ))

      var taskResult: WorkTaskResult
      try:
        taskResult = normalizedResult(
          nodeId,
          input.executors.executors[nodeId](input.graph.findNode(nodeId))
        )
      except CatchableError as exc:
        taskResult = failed(nodeId, message = exc.msg)

      statuses[nodeId] = taskResult.status
      report.results.add(taskResult)
      addEvent(workEvent(
        eventId(input.options.runId, nodeId, "finished"),
        input.graph.id,
        input.options.runId,
        wekTaskFinished,
        variantId = input.graph.variantId,
        nodeId = nodeId,
        status = taskResult.status,
        durationMillis = taskResult.durationMillis,
        message = taskResult.message,
        metrics = taskResult.metrics
      ))

      if input.options.failFast and taskResult.status == wsFailed:
        stopped = true
        break

  var failedCount = 0
  for result in report.results:
    if result.status == wsFailed:
      inc failedCount

  report.status = if failedCount == 0: wsSucceeded else: wsFailed
  addEvent(workEvent(
    "run:" & input.options.runId & ":finished",
    input.graph.id,
    input.options.runId,
    wekRunFinished,
    variantId = input.graph.variantId,
    status = report.status
  ))

  WorkRunOutcome(ok: failedCount == 0, report: report, errors: report.errors)

proc run*(graph: WorkGraph; executors: WorkExecutorRegistry;
    options = defaultWorkRunOptions()): WorkRunOutcome =
  run(initWorkRunInput(graph, executors, options))
