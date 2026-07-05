# Plugins

FlowWorkRunner keeps the core runner small while exposing stable plugin
boundaries for optional packages.

## Core Responsibilities

- Validate and plan in-memory work graphs.
- Execute registered callbacks deterministically.
- Emit run and task events.
- Return reports and errors as data.

## Plugin Responsibilities

Plugins can add behavior around the core without being part of the core package:

- shell or process execution
- remote worker execution
- FlowBrigade-backed task gates
- FlowLogbook event sinks
- FlowSurveyor or Shelfer telemetry bridges
- audit exports
- report exporters
- cloud or enterprise policy integration

## Manifest

Plugins can declare capabilities with `WorkPluginManifest`:

```nim
let manifest = pluginManifest(
  "flowworkrunner-audit",
  "1.0.0",
  capabilities = [wpckEventSink, wpckTelemetry]
)
```

## Event Sink

Event sinks receive events emitted by the core runner:

```nim
var extensions = initWorkExtensionRegistry()
extensions.addEventSink(proc(event: WorkEvent) =
  discard event
)
```

Sink failures are recorded in `WorkRunReport.errors` and do not crash the run.

## Task Gate

Task gates can allow, skip, or fail a task before its executor runs:

```nim
extensions.addTaskGate(proc(node: WorkNode): WorkTaskDecision =
  if node.id == "restricted":
    failTask("denied by policy")
  else:
    allowTask()
)
```

Task gates are intended for policy and control decisions. Expensive execution
work should remain in executors or external runner plugins.
