FROM prom/prometheus:latest
COPY ./prometheus.yml /etc/prometheus/prometheus.yml

HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD sh -c 'nc -z localhost 9090 || exit 1'