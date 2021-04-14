# Adding Observability to Nomad Applications

> Recording of the demo is available on the [hashitalk 2021 website](https://www.hashicorp.com/resources/adding-observability-to-hashicorp-nomad-applications-with-grafana). ([slides](https://docs.google.com/presentation/d/1CSWKew4ID0oKBnQpR-3wUUyF8XpIIPzwzSLsc61yZL8/edit#slide=id.gbc349f7587_0_60))

This repository demonstrates how you can leverage the [Grafana Open Source Observability Stack][oss-grafana] with [Nomad][nomad] workload.

In this demonstration we will deploy an application ([TNS][TNS]) on [Nomad][nomad] along with the [Grafana Stack][oss-grafana]. The [TNS][TNS] application is written in Go and instrumented with:

- Prometheus **Metrics** using [client_golang][client_golang].
- **Logs** using [gokit][gokit] (output format is [logfmt][logfmt]).
- **Traces** using [jaeguer go client][jaeguer_client].

> You can use the instrumentation of your choice such as: [OpenTelemetry][OpenTelemetry], [Zipkin][Zipkin], json logs...

We'll also deploy backends to store collected signals:

- [Prometheus][Prometheus] will scrape **Metrics** using the scrape endpoint.
- [Loki][Loki] will receive **Logs** collected by [Promtail][promtail].
- [Tempo][Tempo] will directly receives **Traces** and Spans.

Finally, we'll deploy [Grafana][oss-grafana] and [provision](provisioning/) it with all our backend datasources and a dashboard to start with.

## Getting Started

For simplicity you'll need to install and configure [vagrant][vagrant].

To get started simply run:

```bash
vagrant up
```

Then you should be able to access:

- TNS app => http://127.0.0.1:8001/
- Nomad   => http://127.0.0.1:4646/
- Consul  => http://127.0.0.1:8500/ui
- Grafana => http://127.0.0.1:3000/
- Prometheus => http://127.0.0.1:9090/
- Promtail => http://127.0.0.1:3200/

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
[client_golang]: https://github.com/prometheus/client_golang
[TNS]: https://github.com/grafana/tns
[gokit]: https://github.com/go-kit/kit/tree/master/log
[jaeguer_client]: https://github.com/jaegertracing/jaeger-client-go
[logfmt]: https://brandur.org/logfmt
[OpenTelemetry]: https://opentelemetry.io/
[Zipkin]: https://zipkin.io/
[Prometheus]: https://prometheus.io/
[Loki]: https://grafana.com/oss/loki/
[Tempo]: https://grafana.com/oss/tempo/

## Troubleshooting

### Grafana shows nothing or TNS keeps crashing because of it can't connect to Tempo

- You may have troubles with your `dns` configuration in the jobs, if your jobs can't talks to each other tries to change the ip to `127.0.0.1` or the internal ip address of your server if using a `VPC` or just removes the `dns` stanza. It's recommanded to use [Consul Connect](https://www.consul.io/docs/connect) to connect every services to each others.

### I can't see the logs in Grafana/Loki

- You may have a different `data_dir` config in your `nomad` configuration. Here it's using `/opt/nomad/data` while we generally sets `/opt/nomad`. If it's your case, change the `volume` stanza of your `tempo` job.
