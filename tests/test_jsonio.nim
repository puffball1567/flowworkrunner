import std/json
import std/unittest

import flowworkrunner

suite "json io":
  test "serializes run reports":
    let report = WorkRunReport(
      schemaVersion: ReportSchemaVersion,
      flowId: "flow",
      runId: "run",
      status: wsSucceeded,
      batches: @[ReadyBatch(index: 0, nodeIds: @["a"])],
      results: @[succeeded("a", durationMillis = 10)],
      events: @[workEvent("e1", "flow", "run", wekTaskFinished,
        nodeId = "a", status = wsSucceeded)]
    )

    let node = parseJson(report.toJsonString())
    check node["schemaVersion"].getInt() == ReportSchemaVersion
    check node["flowId"].getStr() == "flow"
    check node["status"].getStr() == "wsSucceeded"
    check node["batches"][0]["nodeIds"][0].getStr() == "a"
    check node["results"][0]["nodeId"].getStr() == "a"
    check node["events"][0]["kind"].getStr() == "wekTaskFinished"
