FROM mongo:5.0

# Install netcat-openbsd
#RUN apt-get update && apt-get install -y netcat-openbsd

# WORKDIR /usr/src/app
# COPY start-mongodb.sh .
# RUN chmod +x start-mongodb.sh

# Healthcheck definition
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 CMD mongo --eval "db.adminCommand('ping')" || exit 1
#HEALTHCHECK --interval=30s --timeout=5s --retries=3 CMD sh -c 'nc -z localhost 27017 || exit 1'
# HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
#     CMD curl --silent --fail http://localhost:27017/ || exit 1

# ENTRYPOINT [ "./start-mongodb.sh" ]