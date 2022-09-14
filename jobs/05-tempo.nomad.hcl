job "tempo" {
  datacenters = ["dc1"]
  type        = "service"

  group "tempo" {
    count = 1

    network {
      dns {
        servers = ["192.168.100.80", "1.0.0.1", "8.8.8.8"]
      }
      port "tempo" {
          static = "3400"
      }
      port "tempo_grpc" {
          static = "9095"
      }
      port "tempo_write" {
        static = "6831"
      }
      port "tempo_otel_grpc" {
        static = "4217"
        to = "4317"
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "tempo" {
      driver = "docker"

      env {
        JAEGER_AGENT_HOST    = "tempo.service.dc1.consul"
        JAEGER_TAGS          = "cluster=nomad"
        JAEGER_SAMPLER_TYPE  = "probabilistic"
        JAEGER_SAMPLER_PARAM = "1"
      }

      template {
        data = <<EOFT
metrics_generator_enabled: true

server:
  http_listen_port: {{ env "NOMAD_PORT_tempo" }}
  grpc_listen_port: {{ env "NOMAD_PORT_tempo_grpc" }}

distributor:
  receivers:                           # this configuration will listen on all ports and protocols that tempo is capable of.
    jaeger:                            # the receives all come from the OpenTelemetry collector.  more configuration information can
      protocols:                       # be found there: https://github.com/open-telemetry/opentelemetry-collector/tree/main/receiver
        thrift_http:                   #
        grpc:                          # for a production deployment you should only enable the receivers you need!
        thrift_binary:
        thrift_compact:
    zipkin:
    otlp:
      protocols:
        http:
        grpc:
    opencensus:

ingester:
  trace_idle_period: 10s               # the length of time after a trace has not received spans to consider it complete and flush it
  max_block_bytes: 1_000_000           # cut the head block when it hits this size or ...
  max_block_duration: 5m               #   this much time passes

compactor:
  compaction:
    compaction_window: 1h              # blocks in this time window will be compacted together
    max_block_bytes: 100_000_000       # maximum size of compacted blocks
    block_retention: 1h
    compacted_block_retention: 10m

metrics_generator:
  registry:
    external_labels:
      source: tempo
      cluster: nomad_service
  storage:
    path: /tmp/tempo/generator/wal
    remote_write:
      - url: http://prometheus.service.consul:9091/api/v1/write
        send_exemplars: true

storage:
  trace:
    backend: local                     # backend configuration to use
    block:
      bloom_filter_false_positive: .05 # bloom filter false positive rate.  lower values create larger filters but fewer false positives
      index_downsample_bytes: 1000     # number of bytes per index record
      encoding: zstd                   # block encoding/compression.  options: none, gzip, lz4-64k, lz4-256k, lz4-1M, lz4, snappy, zstd, s2
    wal:
      path: /tmp/tempo/wal             # where to store the the wal locally
      encoding: snappy                 # wal encoding/compression.  options: none, gzip, lz4-64k, lz4-256k, lz4-1M, lz4, snappy, zstd, s2
    local:
      path: /tmp/tempo/blocks
    pool:
      max_workers: 100                 # worker pool determines the number of parallel requests to the object store backend
      queue_depth: 10000

overrides:
  metrics_generator_processors: 
    - service-graphs
    - span-metrics
search_enabled: true
        EOFT
        destination = "/local/tempo.yml"      
      }
      
      config {
        image = "grafana/tempo:latest"
        ports = ["tempo", "tempo_write", "tempo_otel_grpc","tempo_grpc"]
        args = [
          "-config.file=/local/tempo.yml"
        ]
      }

      resources {
        cpu    = 200
        memory = 200
      }

      service {
        name = "tempo"
        port = "tempo"
        tags = ["monitoring","prometheus"]

        check {
          name     = "Tempo HTTP"
          type     = "http"
          path     = "/ready"
          interval = "5s"
          timeout  = "2s"

          check_restart {
            limit           = 2
            grace           = "60s"
            ignore_warnings = false
          }
        }
      }
    }
  }
}
