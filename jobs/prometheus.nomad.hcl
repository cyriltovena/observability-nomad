job "prometheus" {
  datacenters = ["dc1"]
  type        = "service"

  group "prometheus" {
    count = 1

    network {
      dns {
        servers = ["172.17.0.1", "8.8.8.8", "8.8.4.4"]
      }
      port "http" {
        static = 9090
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "prometheus" {
      driver = "docker"

      template {
        data        = <<EOTC
scrape_configs:
  - job_name: 'self'
    consul_sd_configs:
      - server: '172.17.0.1:8500'
    relabel_configs:
      - source_labels: [__meta_consul_service_metadata_external_source]
        target_label: source
        regex: (.*)
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
EOTC
        destination = "/local/prometheus.yml"
      }
      config {
        image = "prom/prometheus"
        ports = ["http"]
        args = [
          "--config.file=/local/prometheus.yml",
          "--web.enable-admin-api"
        ]
      }

      resources {
        cpu    = 200
        memory = 200
      }

      service {
        name = "prometheus"
        port = "http"
        tags = ["monitoring"]

        check {
          name     = "prometheus HTTP"
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
