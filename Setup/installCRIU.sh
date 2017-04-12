#!/usr/bin/env bash

##--------------------------------------------------##
## This script will install CRIU from source
##--------------------------------------------------##

set -euo pipefail

# Must run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or use sudo $0" 1>&2
   exit 1
fi

CRIU_SOURCE="https://github.com/xemul/criu.git"
latest_version=$(git ls-remote --tags ${CRIU_SOURCE} | awk '{print $2}' | awk -F/ '{print $NF}' | grep -v '\^{}' | sort -V | tail -n 1) || { echo "Failed to get CRIU latest version."; exit 1; }
install_dir="/opt"

build_n_install() {
    # checkout latest taged version
    git checkout ${latest_version}
    # clean if there was a previous build
    sudo make clean
    # build criu
    sudo make
    # install the libs and binary
    sudo make install-lib install-criu
}

#-------------------------------
# Install CRIU if not installed
#-------------------------------
# Check if CRIU is installed
if [[ ! $(which criu) ]]; then
    echo "CRIU is not installed."
    echo "Installing CRIU ${latest_version}"
    # Install Prerequisites
    sudo apt-get install -y --no-install-recommends \
        git \
        build-essential \
        libprotobuf-dev \
        libprotobuf-c0-dev \
        protobuf-c-compiler \
        protobuf-compiler \
        python-protobuf \
        python-yaml \
        libnl-3-dev \
        libpth-dev pkg-config \
        libcap-dev \
        libaio-dev \
        libnet1-dev \
        asciidoc

    # Clone CRIU
    cd ${install_dir}
    rm -rf criu
    git clone ${CRIU_SOURCE}
    cd criu

    # Install CRIU
    build_n_install

    echo ""
    echo "CRIU install complete."
else # update criu if needed
    #get current version of criu
    installed_version=$(criu --version | grep GitID | awk '{print $2}') || { echo "Failed to get installed verion"; exit 1; }
    echo "CRIU installed version: ${installed_version}"

    if [ "${latest_version}" != "${installed_version}" ]; then
        echo "Updating CRIU with latest version [${latest_version}]"
        cd ${install_dir}
        # download criu if directory doesn't exist
        [ ! -d criu ] && git clone ${CRIU_SOURCE}
        cd criu
        git checkout master
        git pull origin master
        git fetch --all

        # build and install latest version
        build_n_install

        echo ""
        echo "CRIU update complete."
    else
        echo ""
        echo "CRIU already at latest version."
    fi
fi
criu --version
exit 0
