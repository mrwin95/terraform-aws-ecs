#!/bin/bash

# Wait until the lock file is released
while [ -f /data/db/mongod.lock ]; do
  echo "Lock file exists. Waiting for the lock to be released..."
  sleep 5
done

# Start MongoDB
echo "Starting MongoDB..."
exec mongod --replSet rs0 --bind_ip_all --dbpath /data/db
