# Intellectual Property Notes

FlowWorkRunner intentionally uses general workflow and scheduling concepts:

- directed acyclic graphs
- topological readiness
- ready batches
- callback execution
- terminal task states
- required dependency failure propagation

These are common ideas across build tools, workflow engines, task queues, and
job schedulers. The implementation is original and intentionally avoids copying
workflow engine DSLs, scheduler internals, distributed execution protocols, or
runtime behavior from other projects.

If a credible concern is reported, the project should review it promptly and
adjust or remove the disputed behavior when appropriate.
