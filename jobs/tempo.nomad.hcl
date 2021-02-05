job "tempo" {
  datacenters = ["dc1"]
  type        = "service"

  group "tempo" {
    count = 1

    network {
      dns {
        servers = ["172.17.0.1", "8.8.8.8", "8.8.4.4"]
      }
      port "tempo" {}
      port "query" {
        static = "16686"
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "tempo" {
      driver = "docker"

      artifact {
        source      = "https://raw.githubusercontent.com/grafana/tempo/master/example/docker-compose/etc/tempo-local.yaml"
        mode        = "file"
        destination = "/local/tempo.yml"
      }
      config {
        image = "grafana/tempo"
        ports = ["tempo"]
        args = [
          "-config.file=/local/tempo.yml",
          "-server.http-listen-port=${NOMAD_PORT_tempo}",
        ]
      }

      resources {
        cpu    = 200
        memory = 200
      }

      service {
        name = "tempo"
        port = "tempo"
        tags = ["monitoring"]

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

    task "tempo-query" {
      driver = "docker"


      template {
        data        = <<EOTC
backend: "tempo.service.dc1.consul:${NOMAD_PORT_tempo}"
EOTC
        destination = "/local/tempo-query.yml"
      }

      config {
        image = "grafana/tempo-query"
        ports = ["query"]
        args = [
          "--grpc-storage-plugin.configuration-file=/local/tempo-query.yml",
        ]
      }

      resources {
        cpu    = 200
        memory = 200
      }

      service {
        name = "tempo-query"
        port = "query"
        tags = ["monitoring"]

        check {
          name     = "Tempo Query HTTP"
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
