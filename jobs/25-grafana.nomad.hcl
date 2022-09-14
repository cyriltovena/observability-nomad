job "grafana" {
  datacenters = ["dc1"]
  type        = "service"

  group "grafana" {
    count = 1

    network {
      dns {
        servers = ["192.168.100.80", "1.0.0.1", "8.8.4.4"]
      }
      port "http" {
        static = 3000
      }
    }

    restart {
      attempts = 3
      delay    = "20s"
      mode     = "delay"
    }

    task "grafana" {
      driver = "docker"

      config {
        image = "grafana/grafana:latest"
        ports = ["http"]
      }

      env {
        GF_LOG_LEVEL          = "DEBUG"
        GF_LOG_MODE           = "console"
        GF_SERVER_HTTP_PORT   = "${NOMAD_PORT_http}"
        GF_PATHS_PROVISIONING = "/local/grafana/provisioning"
      }

      template {
        data        = <<EOTC
apiVersion: 1
deleteDatasources:
  - name: Tempo
  - name: Prometheus
datasources:
  - name: Prometheus
    type: prometheus
    uid: prom 
    access: proxy
    url: http://prometheus.service.dc1.consul:9091
    jsonData:
      exemplarTraceIdDestinations:
      - name: traceID
        datasourceUid: tempo
  - name: Tempo
    type: tempo
    access: proxy
    url: http://tempo.service.dc1.consul:3400
    uid: tempo
    jsonData:
      httpMethod: GET
      tracesToLogs:
        datasourceUid: 'loki'
        tags: ['job', 'instance', 'pod', 'namespace']
        mappedTags: [{ key: 'service.name', value: 'service' }]
        mapTagNamesEnabled: false
        spanStartTimeShift: '1h'
        spanEndTimeShift: '1h'
        filterByTraceID: false
        filterBySpanID: false
      tracesToMetrics:
        datasourceUid: prom
        tags: [{ key: 'service.name', value: 'service' }, { key: 'job' }]
        queries:
          - name: 'Span Latency Query'
            query: 'sum(rate(traces_spanmetrics_latency_bucket{$__tags}[5m]))'
      serviceMap:
        datasourceUid: 'prom'
      search:
        hide: false
      nodeGraph:
        enabled: true
      lokiSearch:
        datasourceUid: 'loki'
  - name: Loki
    type: loki
    access: proxy
    uid: loki
    url: http://loki.service.dc1.consul:3100
    jsonData:
      derivedFields:
        - datasourceUid: tempo
          matcherRegex: (?:traceID|trace_id)=(\w+)
          name: TraceID
          url: $$${__value.raw}
EOTC
        destination = "/local/grafana/provisioning/datasources/ds.yaml"
      }
      template {
        data  = <<ETOC

ETOC
        destination = "/local/grafana/config/custom.ini"
      }
      artifact {
        source      = "https://raw.githubusercontent.com/alfkonee/observability-nomad/main/provisioning/dashboard.yaml"
        mode        = "file"
        destination = "/local/grafana/provisioning/dashboards/dashboard.yaml"
      }
      artifact {
        source      = "https://raw.githubusercontent.com/alfkonee/observability-nomad/main/provisioning/dashboard.json"
        mode        = "file"
        destination = "/local/grafana/dashboards/tns.json"
      }

      resources {
        cpu    = 100
        memory = 100
      }

      service {
        name = "grafana"
        port = "http"
        tags = ["monitoring","prometheus"]

        check {
          name     = "Grafana HTTP"
          type     = "http"
          path     = "/api/health"
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
