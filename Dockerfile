FROM ghcr.io/zaproxy/zaproxy:stable

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    gettext-base \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /zap/wrk

COPY scripts/ /zap/wrk/scripts/
COPY plans/ /zap/wrk/plans/

RUN chmod +x /zap/wrk/scripts/*.sh && \
    mkdir -p /zap/wrk/reports && \
    chown -R zap:zap /zap/wrk

USER zap

# Pre-install required ZAP add-ons at build time so -silent runtime never stalls on marketplace checks
RUN /zap/wrk/scripts/install-addons.sh

ENTRYPOINT ["/zap/wrk/scripts/entrypoint.sh"]
