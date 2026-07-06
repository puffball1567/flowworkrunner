# FlowWorkRunner

FlowWorkRunner is a small Nim library for executing ready work from directed
flow graphs.

It is part of the **FlowBrigade Toolkit**.

## Status

FlowWorkRunner v0.2.0 is focused on deterministic in-process execution and
execution-shape metrics. Within that scope, it provides:

- graph and task execution primitives
- static ready-batch planning
- wait-on edge failure propagation
- callback-based task executors
- plugin-ready extension points
- non-throwing run outcomes for FlowCaptain-style integration
- run events that can be mapped to FlowLogbook
- run metrics for batch count, max batch width, estimated elapsed time,
  parallelism factor, and success rate
- JSON report export
- examples, tests, design notes, and benchmarks

## v0.1.0 Scope

The first release is intentionally narrow and complete:

- accept an in-memory `WorkGraph`
- validate graph shape before execution
- compute ready batches from directed dependencies
- run registered task executors in dependency order
- skip downstream work when a required `waitOn` edge source fails
- report missing executors as data, not uncaught exceptions
- produce a `WorkRunReport` with `schemaVersion = 1`
- expose plugin manifests, event sinks, and task gates for extensions

FlowWorkRunner does not launch shell commands, manage remote workers, persist
history, or perform adaptive scheduling in v0.1.0.

## Example

```nim
import flowworkrunner

var graph = initWorkGraph("daily-report")
graph.nodes.add(workNode("extract"))
graph.nodes.add(workNode("publish"))
graph.edges.add(workEdge("extract-publish", "extract", "publish", waitOn = true))

var executors = initWorkExecutorRegistry()
executors.register("extract", proc(node: WorkNode): WorkTaskResult =
  succeeded(node.id, message = "loaded input")
)
executors.register("publish", proc(node: WorkNode): WorkTaskResult =
  succeeded(node.id, message = "published report")
)

let outcome = run(initWorkRunInput(graph, executors))
if outcome.ok:
  echo outcome.report.toJsonString()
  echo outcome.report.workRunMetrics().parallelismFactor
else:
  echo outcome.errors
```

## Integration

FlowCaptain should use `run(input) -> WorkRunOutcome` as the integration
boundary. The outcome contains `ok`, `report`, and `errors`, so callers can
reject invalid graphs or missing executors without relying on exception control
flow.

FlowLogbook adapters can map `WorkEvent` values to run events. FlowSurveyor can
consume equivalent graph and event data for analysis.

## Extension Points

The core package includes small extension points so external packages can add
capabilities without changing the runner core:

- plugin manifests describe optional packages and capabilities
- event sinks receive run and task events
- task gates can allow, skip, or fail a task before execution

These hooks are intended for FlowCaptain, Shelfer, and optional plugin packages.
Examples of plugin-side responsibilities include shell execution, cloud workers,
custom security policy, audit export, BI reporting, and external telemetry.

## Requirements

FlowWorkRunner only depends on Nim's standard library.

## Development

```bash
nimble test
nimble examples
nimble bench
```

## Intellectual Property Notes

FlowWorkRunner uses general, well-known workflow concepts: directed acyclic
graphs, topological readiness, callback execution, terminal task states, and
failure propagation along required dependencies.

It does not copy workflow engine code, DSLs, schedulers, or distributed runtime
behavior from other projects.
