FROM redis:latest

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD redis-cli ping || exit 1