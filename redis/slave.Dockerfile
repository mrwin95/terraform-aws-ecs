FROM redis:latest

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD redis-cli ping || exit 1

ENV REDIS_MASTER_HOST=redis-master.redis.local
ENTRYPOINT [ "sh", "-c", "redis-server --replicaof $REDIS_MASTER_HOST 6379" ]