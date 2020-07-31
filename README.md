Run the benchmarks:

```
opa bench 'data.hooks.target.violation' -i input.json -d constraints.rego -d gatekeeper.rego -d template.rego -d data_1x.json
```

Results:

| # of constraints | Latency (ns) |
| --- | --- |
| 100 | 100,137,817 |
| 10 | 9,189,042 |
| 1 | 956,088 |