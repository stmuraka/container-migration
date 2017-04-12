#!/usr/bin/env bash
set -euo pipefail

#--------------------------------------------------
# Updates docker engine to run in experimental mode
#--------------------------------------------------

# Must run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or use sudo $0" 1>&2
   exit 1
fi

# Check Ubuntu version
os_distro=$(lsb_release -a 2>/dev/null | grep -i 'Distributor' | cut -d ':' -f2 | awk '{print $1}') || { echo "Not an Ubuntu distro"; exit 1; }
[[ "${os_distro}" != "Ubuntu" ]] && { echo "Not an Ubuntu distro"; exit 1; }

ubuntu_version=$(lsb_release -a 2>/dev/null | grep -i 'release' | awk '{print $2}') || { echo "Could not determine the release"; exit 1; }

# Check if Docker is installed
if [[ $(which docker) ]]; then
    # get docker version
    docker_version=$(docker -v | awk '{print $3}' | tr -d ',')
    ver=${docker_version%.*}
    docker_major=${ver%.*}
    docker_minor=${ver#*.}

    # Check if docker version > 1.13
    [[ "${docker_major}" -eq "1" ]] && [[ "${docker_minor}" -lt "13" ]] && { echo "Docker version must be >= 1.13"; exit 1; }

    # Update Docker daemon options
    echo "Updating Docker options"
    # Add --experimental flag to docker opts
    if [[ $(grep -q '^DOCKER_OPTS' /etc/default/docker) ]]; then
        # Append to DOCKER_OPTS
        sed-i -e '/^DOCKER_OPTS.*/ s/"$/ --experimental"/' /etc/default/docker
    else
        # Add DOCKER_OPTS
        echo 'DOCKER_OPTS="--experimental"' >> /etc/default/docker
    fi

    if [[ "${ubuntu_version%.*}" -ge "15" ]]; then
        # systemd
        # update Docker unit file
        docker_dropin_dir="/etc/systemd/system/docker.service.d"
        docker_dropin_unit="docker.conf"
        # Create Docker drop-in directory
        mkdir -p ${docker_dropin_dir}

        # check if /etc/sysconfig/docker exists
        dropin_unit="${docker_dropin_dir}/${docker_dropin_unit}"
        echo "Creating docker drop-in: ${dropin_unit}"
        if [ ! -f ${dropin_unit} ]; then
            cp /lib/systemd/system/docker.service ${dropin_unit}
            sed -i -e "/ExecStart=/i EnvironmentFile=-/etc/default/docker" ${dropin_unit}
            sed -i -e "/ExecStart=/ s/$/ \$DOCKER_OPTS/" ${dropin_unit}
            sed -i -e "/ExecStart=/i ExecStart=" ${dropin_unit}
        else
            cp ${dropin_unit} ${dropin_unit}.bak
            if ! grep -q '^EnvironmentFile=-\/etc\/default\/docker' ${dropin_unit}; then
                sed -i -e "/ExecStart=/i EnvironmentFile=-/etc/default/docker" ${dropin_unit}
            fi
            if ! grep -q '^ExecStart=.*\$DOCKER_OPTS' ${dropin_unit}; then
                sed -i -e "/ExecStart=/ s/$/ \$DOCKER_OPTS/" ${dropin_unit}
            fi
            if ! grep -q '^ExecStart=$' ${dropin_unit}; then
                sed -i -e "/ExecStart=/i ExecStart=" ${dropin_unit}
            fi
        fi
        systemctl daemon-reload
        systemctl restart docker
        systemctl status docker
    else
        # upstart
        # Restart Docker
        restart docker
    fi
else
    echo "ERROR: docker not found in path. Please fix path or install docker"
    exit 1
fi

exit 0
