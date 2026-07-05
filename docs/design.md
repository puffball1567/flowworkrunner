# Design

FlowWorkRunner executes work that is ready according to a directed graph.

## Goals

- Validate a graph before execution.
- Compute deterministic ready batches.
- Execute registered task callbacks in dependency order.
- Treat `waitOn` edges as required dependencies for failure propagation.
- Return reports and errors as data for FlowCaptain-style integration.
- Produce events that can be mapped into FlowLogbook.
- Provide stable extension points for plugins without embedding plugin behavior.
- Stay independent from shell execution, remote workers, databases, and web
  frameworks.

## Non-goals

- Launching OS processes
- Managing remote worker pools
- Persisting run history
- Replacing FlowDependency or FlowLogbook
- Adaptive scheduling
- Dashboard rendering

## Core Model

```text
WorkGraph + WorkExecutorRegistry -> WorkRunOutcome
```

`readyBatches` describes which nodes can be considered parallelizable. The
v0.1.0 runner executes callback functions deterministically in batch order
instead of starting threads.

## waitOn

Every edge participates in readiness. The `waitOn` flag controls failure
propagation:

- `waitOn = true`: the target is skipped when the source fails or is skipped.
- `waitOn = false`: the target may still run after the source reaches a terminal
  state.

This keeps the model useful for "parallel but this handoff is required" cases
without adding a domain-specific workflow language.

## Integration Boundary

FlowCaptain should call `run(input) -> WorkRunOutcome`. The outcome contains:

- `ok`
- `report`
- `errors`

Invalid graphs, cycles, missing executors, and callback failures are returned as
data rather than uncaught exceptions.

## Plugin Boundary

The core runner includes extension points, but not plugin implementations:

- `WorkPluginManifest` lets an extension declare its name, version, and
  capabilities.
- `WorkEventSink` receives events without controlling the core run loop.
- `WorkTaskGate` can allow, skip, or fail a task before its executor runs.

This keeps the open core valuable on its own while leaving room for separate
plugins such as shell runners, remote worker adapters, FlowBrigade policy gates,
FlowLogbook sinks, FlowSurveyor/Shelfer telemetry bridges, and report exporters.

Event sink failures are captured in `WorkRunReport.errors` and do not crash the
run. Task gates are control points and can intentionally skip or fail tasks.
