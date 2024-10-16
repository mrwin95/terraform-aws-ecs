# How to connect to docker container hosting on ecs

ecs exec --task <task id> --container redis-master --interactive --tty -- /bin/bash