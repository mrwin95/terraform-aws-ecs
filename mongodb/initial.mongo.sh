#!/bin/bash
# Initialize MongoDB Replica Set
mongo --eval 'rs.initiate({_id : "rs0", members: [{ _id : 0, host : "mongodb-master.mongodb.local:27017" }, { _id : 1, host : "mongodb-slave.mongodb.local:27017" }, { _id : 2, host : "mongodb-slave.mongodb.local:27017" }]})'
