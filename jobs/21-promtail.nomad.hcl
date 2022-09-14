job "promtail" {
  datacenters = ["dc1"]
  # Runs on all nomad clients
  type = "system"

  group "promtail" {
    count = 1

    network {
      dns {
        servers = ["192.168.100.80", "1.0.0.1", "8.8.4.4"]
      }
      port "http" {
        static = 3200
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "promtail" {
      driver = "docker"

      env {
        HOSTNAME = "${attr.unique.hostname}"
      }
      template {
        data        = <<EOTC
positions:
  filename: /data/positions.yaml

clients:
  - url: http://loki.service.dc1.consul:3100/loki/api/v1/push

scrape_configs:
- job_name: 'nomad-logs'
  consul_sd_configs:
    - server: '192.168.100.80:8500'
      token: '[REPLACE_WITH_CONSUL_TOKEN]'
  relabel_configs:
    - source_labels: [__meta_consul_node]
      target_label: __host__
    - source_labels: [__meta_consul_service_metadata_external_source]
      target_label: source
      regex: (.*)
      replacement: '$1'
    - source_labels: [__meta_consul_service_id]
      regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
      target_label:  'task_id'
      replacement: '$1'
    - source_labels: [__meta_consul_tags]
      regex: ',(app|monitoring),'
      target_label:  'group'
      replacement:   '$1'
    - source_labels: [__meta_consul_service]
      target_label: job
    - source_labels: ['__meta_consul_node']
      regex:         '(.*)'
      target_label:  'instance'
      replacement:   '$1'
    - source_labels: [__meta_consul_service_id]
      regex: '_nomad-task-([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})-.*'
      target_label:  '__path__'
      replacement: '/nomad/alloc/$1/alloc/logs/*std*.{?,??}'
EOTC
        destination = "/local/promtail.yml"
      }

      config {
        image = "grafana/promtail:latest"
        ports = ["http"]
        args = [
          "-config.file=/local/promtail.yml",
          "-server.http-listen-port=${NOMAD_PORT_http}",
        ]
        volumes = [
          "/data/promtail:/data",
          "/opt/nomad/data/:/nomad/"
        ]
      }

      resources {
        cpu    = 50
        memory = 100
      }

      service {
        name = "promtail"
        port = "http"
        tags = ["monitoring","prometheus"]

        check {
          name     = "Promtail HTTP"
          type     = "http"
          path     = "/targets"
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
