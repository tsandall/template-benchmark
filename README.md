# Example `opa bench` command

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

## Use `object.get` instead of `get_default` Rego function

| # of constraints | Latency (ns) |
| --- | --- |
| 1 | 341,791 |
| 10 | 2,886,927 |
| 100 | 30,387,561 |

## Use `.` and `not` instead of `has_field` Rego function

| # of constraints | Latency (ns) |
| --- | --- |
| 1 | 279,363 |
| 10 | 2,228,619 |
| 100 | 23,188,588 |

> The semantics aren't quite the same however none of has_field cases should be affected (since the fields being checked are never boolean valued.)