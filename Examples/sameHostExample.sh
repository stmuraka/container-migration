#!/usr/bin/env bash
set -euo pipefail

#---------------------------------------------------------------------------------------
# This script demonstrates a simple checkpoint-restore of a container running on a host
# 1. A container called "simple" will be started as a counter.
# 2. A checkpoint named "first" will be created when it is stopped.
# 3. The container will resume from the checkpoint and resume counting.
#---------------------------------------------------------------------------------------

container_name="simple"
checkpoint_name="first"

# Simple example of checkpoint
checkpoint() {
    echo "Checkpoint running container"
    echo "$ docker checkpoint create ${container_name} ${checkpoint_name}"
    docker checkpoint create ${container_name} ${checkpoint_name}
}

restore() {
    echo "Starting container [${container_name}] from checkpoint"
    echo "$ docker start --checkpoint ${checkpoint_name} ${container_name}"
    docker start --checkpoint ${checkpoint_name} ${container_name}
}

destroy() {
    docker rm -fv ${container_name}
    exit 1
}

pause() {
    echo "${1}"
    read -n1 -rsp $'\n' key
}

echo "This is a simple example of checkpoint"
echo ""
echo "Starting a container that increments a counter by 1 every second..."
echo "$ docker run -d --name ${container_name} busybox /bin/sh -c 'i=0; while true; do echo \$i; i=\$((i+1)); sleep 1; done'"
docker run -d --name ${container_name} busybox /bin/sh -c 'i=0; while true; do echo $i; i=$((i+1)); sleep 1; done'
echo ""

trap destroy INT

echo "Press any key to checkpoint the container..."
echo ""

echo "Container logs..."
echo "$ docker logs -f ${container_name}"
docker logs -f ${container_name} 2>&1 &

# Checkpoint
pause ""
echo ""
echo ""
checkpoint
echo ""

docker ps -a
echo ""

# Restore
pause "Press any key to restore the container..."
restore

docker logs -f ${container_name} 2>&1 &

echo ""
pause "Press any key to exit and remove the container"
echo ""
destroy
