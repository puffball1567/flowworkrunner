import std/sets

import ./types
import ./validation

type
  WorkPluginCapabilityKind* = enum
    wpckExecutorProvider,
    wpckEventSink,
    wpckTaskGate,
    wpckReportExporter,
    wpckScheduler,
    wpckFlowControl,
    wpckTelemetry

  WorkPluginManifest* = object
    name*: string
    version*: string
    capabilities*: seq[WorkPluginCapabilityKind]
    metadata*: seq[KeyValue]

  WorkTaskDecisionKind* = enum
    wtdAllow,
    wtdSkip,
    wtdFail

  WorkTaskDecision* = object
    kind*: WorkTaskDecisionKind
    reason*: string

  WorkEventSink* = proc(event: WorkEvent)
  WorkTaskGate* = proc(node: WorkNode): WorkTaskDecision

  WorkExtensionRegistry* = object
    plugins*: seq[WorkPluginManifest]
    eventSinks*: seq[WorkEventSink]
    taskGates*: seq[WorkTaskGate]

proc allowTask*(): WorkTaskDecision =
  WorkTaskDecision(kind: wtdAllow)

proc skipTask*(reason: string): WorkTaskDecision =
  WorkTaskDecision(kind: wtdSkip, reason: reason)

proc failTask*(reason: string): WorkTaskDecision =
  WorkTaskDecision(kind: wtdFail, reason: reason)

proc pluginManifest*(name, version: string;
    capabilities: openArray[WorkPluginCapabilityKind] = [];
    metadata: openArray[KeyValue] = []): WorkPluginManifest =
  WorkPluginManifest(
    name: name,
    version: version,
    capabilities: @capabilities,
    metadata: @metadata
  )

proc initWorkExtensionRegistry*(): WorkExtensionRegistry =
  WorkExtensionRegistry()

proc register*(registry: var WorkExtensionRegistry; plugin: WorkPluginManifest) =
  registry.plugins.add(plugin)

proc addEventSink*(registry: var WorkExtensionRegistry; sink: WorkEventSink) =
  registry.eventSinks.add(sink)

proc addTaskGate*(registry: var WorkExtensionRegistry; gate: WorkTaskGate) =
  registry.taskGates.add(gate)

proc hasCapability*(plugin: WorkPluginManifest;
    capability: WorkPluginCapabilityKind): bool =
  for item in plugin.capabilities:
    if item == capability:
      return true

proc validate*(registry: WorkExtensionRegistry): ValidationResult =
  var errors: seq[string]
  var names = initHashSet[string]()

  for index, plugin in registry.plugins:
    if plugin.name.len == 0:
      errors.add("plugin[" & $index & "]: name is required")
    elif plugin.name in names:
      errors.add("plugin[" & $index & "]: duplicate plugin name: " & plugin.name)
    else:
      names.incl(plugin.name)

    if plugin.version.len == 0:
      errors.add("plugin[" & $index & "]: version is required")

  if errors.len == 0:
    return valid()
  invalid(errors)

proc evaluateTaskGates*(registry: WorkExtensionRegistry;
    node: WorkNode): WorkTaskDecision =
  for gate in registry.taskGates:
    let decision = gate(node)
    if decision.kind != wtdAllow:
      return decision
  allowTask()

proc emit*(registry: WorkExtensionRegistry; event: WorkEvent;
    errors: var seq[string]) =
  for sink in registry.eventSinks:
    try:
      sink(event)
    except CatchableError as exc:
      errors.add("event sink failed: " & exc.msg)
