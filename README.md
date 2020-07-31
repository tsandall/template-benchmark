Run the benchmarks:

```
opa bench 'data.hooks.target.violation' -i input.json -d constraints.rego -d gatekeeper.rego -d template.rego -d data_1x.json
```

# Results

## Baseline

| # of constraints | Latency (ns) |
| --- | --- |
| 1 | 956,088 |
| 10 | 9,189,042 |
| 100 | 100,137,817 |

## Use `object.get` instead of Rego function

| # of constraints | Latency (ns) |
| --- | --- |
| 1 | 341,791 |
| 10 | 2,886,927 |
| 100 | 30,387,561 |