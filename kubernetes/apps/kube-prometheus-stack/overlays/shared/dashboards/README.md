# Dashboards

## WAN Health (`wan-health.json`)

`https://grafana.shared.h.svenlito.com/d/wan-health`

Reads the recording rules in `prometheusrule-wan.yaml`. Uptime/coverage tiles
are always shown in pairs — a coverage figure below its matching uptime
figure — because an uptime number on its own can't tell you whether the Pi
was buffering during an outage.

### ISP-facing uptime/loss query

Run this **ad hoc, at report time** — not from the `wan_rollups_90d`
recording rules. Those evaluate on wall-clock time and are never re-run over
late-arriving backfill, so a buffered outage is baked in wrong either way. A
fresh range query reads sample timestamps, so it sees late arrivals wherever
they actually belong in the window.

```promql
1 - (
  sum(increase(smokeping_response_duration_seconds_count{host="192.168.8.1"}[90d])) /
  sum(increase(smokeping_requests_total{host="192.168.8.1"}[90d]))
)
```

Always publish `instance:wan_coverage:ratio1h` alongside it, so the reader
can see how much of the window is actually measured.
