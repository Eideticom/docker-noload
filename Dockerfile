#
# Userspace RMDA (and NVMe-oF) Dockerfile
#
# https://github.com/eideticom/docker-rdma
#
# This Dockerfile creates a container full of useful tools for
# getting RDMA up and running inside a container. Also contains tools
# for NVMe over Fabrics etc.
#

# Pull base image (use Ubuntu LTS).

FROM ubuntu:16.04

# Set the maintainer

MAINTAINER Stephen Bates <stephen@eideticom.com>

# Install the packages we want and need to get RDMA running plus some
# useful PCIe, NVMe and NVMe-oF packages. Note that we use Jason
# Gunthorpe's rdma-core project to provide much of the user-space code
# needed for RDMA.

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    dh-make \
    dh-systemd \
    gcc \
    git \
    infiniband-diags \
    libncurses5-dev \
    libnl-3-dev \
    libnl-route-3-dev \
    libudev-dev \
    net-tools \
    ninja-build \
    nvme-cli \
    pciutils \
    perftest \
    pkg-config \
    python \
    valgrind \
    strace \
    sudo \
    wget

# Install rdma-core. For now get this from GitHub since we don't have
# a package. We build a known good tag for consistency reasons as
# master continiously moves. Also use dpkg-buildpackage to generate
# the .deb files to install.

WORKDIR /root
RUN mkdir rdma-core
WORKDIR /root/rdma-core
RUN git init && \
    git remote add origin https://github.com/linux-rdma/rdma-core.git
RUN git fetch origin
RUN git checkout -b rdma v14
WORKDIR /root
RUN tar cvfz rdma-core_14.orig.tar.gz rdma-core
WORKDIR /root/rdma-core
RUN dpkg-buildpackage -d
WORKDIR /root/
RUN dpkg -i --force-overwrite \
    rdma-core_14-1_amd64.deb \
    libibverbs1_14-1_amd64.deb \
    libibcm1_14-1_amd64.deb \
    ibverbs-utils_14-1_amd64.deb \
    ibverbs-providers_14-1_amd64.deb \
    rdmacm-utils_14-1_amd64.deb \
    librdmacm1_14-1_amd64.deb \
    libibumad3_14-1_amd64.deb

# Install the switchtec-user and nvmetcli cli program via github. This
# is because  we don't have packages for them yet.

WORKDIR /root
RUN git clone https://github.com/Microsemi/switchtec-user.git
WORKDIR /root/switchtec-user
RUN make install

WORKDIR /root
RUN git clone git://git.infradead.org/users/hch/nvmetcli.git

# Now add a local user called rdma-user so we don't have to execute things
# as root inside the container. We also create a rdma group so we can
# give the user access to H/W as needed.

# RUN useradd -ms /bin/bash rdma-user
# RUN echo "rdma-user:rdma" | chpasswd
# RUN adduser rdma-user sudo
