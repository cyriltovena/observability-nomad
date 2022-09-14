job "tns" {
  datacenters = ["dc1"]
  type        = "service"

  group "tns" {
    count = 1

    network {
      dns {
        servers = ["192.168.100.80", "1.0.0.1", "8.8.4.4"]
      }
      port "db" {
        static = 8000
      }

      port "app" {
        static = 8001
      }

      port "loadgen" {
        static = 8002
      }
    }

    restart {
      attempts = 5
      interval = "10s"
      delay    = "2s"
      mode     = "delay"
    }

    task "db" {
      driver = "docker"
      env {
        JAEGER_AGENT_HOST    = "tempo.service.dc1.consul"
        JAEGER_TAGS          = "cluster=nomad"
        JAEGER_SAMPLER_TYPE  = "probabilistic"
        JAEGER_SAMPLER_PARAM = "1"
      }
      config {
        image = "grafana/tns-db:latest"
        ports = ["db"]

        args = [
          "-log.level=debug",
          "-server.http-listen-port=${NOMAD_PORT_db}",
        ]
      }

      service {
        name = "db"
        port = "db"
        tags = ["app","prometheus"]
      }
    }

    task "app" {
      driver = "docker"
      env {
        JAEGER_AGENT_HOST    = "tempo.service.dc1.consul"
        JAEGER_TAGS          = "cluster=nomad"
        JAEGER_SAMPLER_TYPE  = "probabilistic"
        JAEGER_SAMPLER_PARAM = "1"
      }
      config {
        image = "grafana/tns-app:latest"
        ports = ["app"]

        args = [
          "-log.level=debug",
          "-server.http-listen-port=${NOMAD_PORT_app}",
          "http://db.service.dc1.consul:${NOMAD_PORT_db}",
        ]
      }

      service {
        name = "app"
        port = "app"
        tags = ["app","prometheus"]
      }
    }

    task "loadgen" {
      driver = "docker"
      env {
        JAEGER_AGENT_HOST    = "tempo.service.dc1.consul"
        JAEGER_TAGS          = "cluster=nomad"
        JAEGER_SAMPLER_TYPE  = "probabilistic"
        JAEGER_SAMPLER_PARAM = "1"
      }
      config {
        image = "grafana/tns-loadgen:latest"
        ports = ["loadgen"]

        args = [
          "-log.level=debug",
          "-server.http-listen-port=${NOMAD_PORT_loadgen}",
          "http://app.service.dc1.consul:${NOMAD_PORT_app}",
        ]
      }

      service {
        name = "loadgen"
        port = "loadgen"
        tags = ["app","prometheus"]
      }
    }
  }
}
