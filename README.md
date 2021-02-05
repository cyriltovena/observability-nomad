# Adding Observability to Nomad Applications


nomad ui: http://localhost:4646/

consul ui: http://localhost:8500/ui

## Requirements

[Promtail][promtail] need to access host logs folder. (alloc/{task_id}/logs)
By default the docker driver in nomad doesn't allow mounting volumes.
In this example we have enabled it using the plugin stanza:

```hcl
  plugin "docker" {
    config {
      volumes {
        enabled      = true
      }
    }
  }
```

However you can also simply run Promtail binary on the host manually too or use nomad [`host_volume`][host_volume] feature.

Promtail also needs to save tail positions in a file, you should make sure this file is always the same between restart.
Again in this example we're using a host path mounted in the container to persist this file,

[promtail]: https://grafana.com/docs/loki/latest/clients/promtail/
[host_volume]: https://www.nomadproject.io/docs/configuration/client#host_volume-stanza
