#!/usr/bin/env bash
set -euo pipefail

#---------------------------------------------------------------------------------------
# This script demonstrates how a container can be checkpointed,
# migrated, and resumed on anther host.
#
# **Prerequisite: SSH between hosts must be configured without a password/passphrase
#
# 1. A container called "simple" will be started as a counter.
# 2. A checkpoint named "first" will be created when it is stopped.
# 3. The container and checkpoint metadata is transferred to another host.
# 4. The container is restored on the remote host and resumes counting.
#---------------------------------------------------------------------------------------

container_name="simple"
checkpoint_name="first"
container_image="busybox"
checkpoint_tar=""

# Simple example of checkpoint
checkpoint() {
    echo "Checkpoint running container"
    echo "$ docker checkpoint create ${container_name} ${checkpoint_name}"
    docker checkpoint create ${container_name} ${checkpoint_name}
}

migrate() {
    echo "Migrating container checkpoint..."

    # Migrate to which host?
    echo -n "Enter host (IP|hostname) to migrate to: "
    read migration_host

    # check ping reachability
    [[ ! $(ping -c 1 ${migration_host} 2>/dev/null) ]] && { echo "Can not reach ${migration_host}"; exit 1; }

    # check ssh connectivity
    [ ! "$(ssh -q ${migration_host} echo 'ok')" == "ok" ] && { echo "Unable to SSH to ${migration_host}"; exit 1; }

    # Attempt to copy over
    scp /tmp/${checkpoint_tar} ${migration_host}:/tmp/
}

restore() {
    echo "Starting container [${container_name}] on ${migration_host} from checkpoint [${checkpoint_name}]"
    # Create new container on host with same container name
    echo "$ docker create --name ${container_name} ${container_image}"
    remote_container_id=$(ssh ${migration_host} "docker create --name ${container_name} ${container_image}")

    # Unpack backup
    ssh -t ${migration_host} "sudo tar -zxf /tmp/${checkpoint_tar} -C /var/lib/docker/containers/${remote_container_id}/checkpoints/"

    # Start container from checkpoint
    ssh ${migration_host} "docker start --checkpoint ${checkpoint_name} ${container_name}"
}

destroy() {
    docker rm -fv ${container_name}
    ssh ${migration_host} "docker rm -fv ${container_name}"
    exit 1
}

pause() {
    echo "${1}"
    read -n1 -rsp $'\n' key
}

echo "This is an example of contianer migration in action"
echo ""
echo "Starting a container that increments a counter by 1 every second..."
echo "$ docker run -d --name ${container_name} ${container_image} /bin/sh -c 'i=0; while true; do echo \$i; i=\$((i+1)); sleep 1; done'"
docker run -d --name ${container_name} ${container_image} /bin/sh -c 'i=0; while true; do echo $i; i=$((i+1)); sleep 1; done'
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

# Get container ID
container_id=$(docker inspect -f '{{.Id}}' ${container_name})

# Make backup of checkpoint
checkpoint_tar="${container_id}.${checkpoint_name}.tgz"
sudo tar -zcf /tmp/${checkpoint_tar} -C /var/lib/docker/containers/${container_id}/checkpoints/ ${checkpoint_name}/

# Migrate
pause "Press any key to migrate the container checkpoint..."
migrate

# Restore
pause "Press any key to restore the container checkpoint..."
restore

ssh ${migration_host} "docker logs -f ${container_name} 2>&1 &"

echo ""
pause "Press any key to exit and remove the container"
echo ""
destroy
