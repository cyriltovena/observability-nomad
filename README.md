# Adding Observability to Nomad Applications

This repository demonstrates how you can leverage the [Grafana Open Source Observability Stack][oss-grafana] with [Nomad][nomad] workload.

For simplicity you'll need vagrant

To get started simply run:

```bash
vagrant up
```

Then you should be able to access:

- Grafana => http://127.0.0.1:3000/
- Nomad   => http://127.0.0.1:4646/
- Consul  => http://127.0.0.1:8500/ui

You can go to the Nomad UI Jobs page to see all running jobs.

![alt text][nomad-grafana]

## Nomad Client Configuration

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
[nomad]: https://www.nomadproject.io/
[oss-grafana]: https://grafana.com/oss/
[vagrant]: https://www.vagrantup.com/
[nomad-grafana]: ./doc/nomad-grafana.png
