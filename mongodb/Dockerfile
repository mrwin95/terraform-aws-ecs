FROM mongo:latest

# WORKDIR /usr/src/app
# COPY start-mongodb.sh .
# RUN chmod +x start-mongodb.sh

# Healthcheck definition
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 CMD mongo --eval "db.adminCommand('ping')" || exit 1

# ENTRYPOINT [ "./start-mongodb.sh" ]