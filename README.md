# container-migration
This project contains scripts that help demonstrate the ability to migrate (checkpoint-restore) a Docker container

## Prerequisites:
 - Docker 1.13+ installed. -- *See [here](https://docs.docker.com/engine/installation/) for installation instructions*

## Files:
- **[Setup/](./Setup/)**
    - *Note: Scripts assume that Docker is running on Ubuntu hosts*
    - **[`installCRIU.sh`](./Setup/installCRIU.sh)** - Installs [CRIU](https://criu.org) from source
    - **[`updateDockerEngine.sh`](./Setup/updateDockerEngine.sh)** - Updates `dockerd` to run in *experimental* mode


- **[Examples/](./Examples/)**
    - **[`sameHostExample.sh`](./Examples/sameHostExample.sh)** - Performs a simple checkpoint/restore of a container on a single host
    - **[`migrateExample.sh`](./Examples/migrateExample.sh)** - Checkpoints a running container on one host and restores it on another host
