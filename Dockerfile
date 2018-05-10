#
# Userspace Dockerfile for Eideticom NoLoad work
#
# https://github.com/eideticom/docker-noload
#
# This Dockerfile creates a container full of useful tools for
# getting Eideticom NoLoad related tooling up and running inside a
# container. Also contains tools for generic RDMA, NVMe and NVMe over
# Fabrics etc.
#

# Pull base image (use Ubuntu LTS).

FROM ubuntu:18.04

# Set the maintainer

LABEL maintainer="Stephen Bates <stephen@eideticom.com>"

# Install the packages we want and need to get RDMA running plus some
# useful PCIe, NVMe and NVMe-oF packages. Note that we use Jason
# Gunthorpe's rdma-core project to provide much of the user-space code
# needed for RDMA.

RUN apt-get update && apt-get install -y \
    apt-utils \
    autoconf \
    build-essential \
    cmake \
    dh-make \
    dh-systemd \
    ethtool \
    emacs-nox \
    gcc \
    git \
    htop \
    kmod \
    iputils-ping \
    libaio-dev \
    libncurses5-dev \
    libmuparser2v5 \
    libnl-3-dev \
    libnl-route-3-dev \
    libudev-dev \
    libglib2.0-0 \
    libglib2.0-dev \
    libtool \
    libopensm5a \
    libopensm-dev \
    libudev-dev \
    net-tools \
    ninja-build \
    pciutils \
    pkg-config \
    psmisc \
    python \
    python-docutils \
    valgrind \
    strace \
    sudo \
    sysstat \
    tmux \
    traceroute \
    tree \
    udev \
    vim \
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
RUN git checkout -b rdma v17
WORKDIR /root
RUN tar cvfz rdma-core_17.0.orig.tar.gz rdma-core
WORKDIR /root/rdma-core
RUN dpkg-buildpackage -d
WORKDIR /root/
RUN dpkg -i --force-overwrite \
    rdma-core_17.0-1_*.deb \
    libibverbs1_17.0-1_*.deb \
    libibverbs-dev_17.0-1_*.deb \
    ibverbs-utils_17.0-1_*.deb \
    ibverbs-providers_17.0-1_*.deb \
    rdmacm-utils_17.0-1_*.deb \
    librdmacm1_17.0-1_*.deb \
    librdmacm-dev_17.0-1_*.deb \
    libibumad3_17.0-1_*.deb \
    libibumad-dev_17.0-1_*.deb

# Install infiniband-diags and perftest. Both of these are now
# upstreamed on the linux-rdma GitHub account.

WORKDIR /root
RUN mkdir infiniband-diags
WORKDIR /root/infiniband-diags
RUN git init && \
    git remote add origin https://github.com/linux-rdma/infiniband-diags.git
RUN git fetch origin
RUN git checkout -b diags 2.0.0
RUN ./autogen.sh
RUN ./configure
  # Next two lines are a hack to get the build to work
RUN ln -s /usr/include/infiniband/complib /usr/local/include/complib
RUN ln -s /usr/include/infiniband/iba /usr/local/include/iba
RUN make
RUN make install

WORKDIR /root
RUN mkdir perftest
WORKDIR /root/perftest
RUN git init && \
    git remote add origin https://github.com/sbates130272/perftest.git
RUN git fetch origin
RUN git checkout -b perftest origin/rdma-cm-client-bind
RUN ./autogen.sh
RUN ./configure
RUN make
RUN make install

# Install mstflint. Now that Mellanox have open-sourced this we can
# pull it direct fromm GitHub

WORKDIR /root
RUN mkdir mstflint
WORKDIR /root/mstflint
RUN git init && \
    git remote add origin https://github.com/Mellanox/mstflint.git
RUN git fetch origin
RUN git checkout -b mstflint v4.8.0-2
RUN ./autogen.sh
RUN ./configure
RUN make
RUN make install

# Install the switchtec-user and nvmetcli cli program via github. This
# is because  we don't have packages for them yet. Also install
# nvme-cli via GitHub and add the Eideticom plug-in to it. Also
# install the NVMe-oF performance monitoring tool.

WORKDIR /root
RUN git clone https://github.com/Microsemi/switchtec-user.git
WORKDIR /root/switchtec-user
RUN git checkout -b switchtec 7e4342e5
RUN ./configure && make && make install

WORKDIR /root
RUN git clone git://git.infradead.org/users/hch/nvmetcli.git

WORKDIR /root
RUN mkdir nvme-cli
WORKDIR /root/nvme-cli
RUN git init && \
    git remote add origin https://github.com/linux-nvme/nvme-cli.git && \
    git remote add eid https://github.com/Eideticom/nvme-cli.git
RUN git fetch origin && git fetch eid
RUN git checkout -b nvme-cli 7fb65f83
RUN make && make install

WORKDIR /root
RUN mkdir nvmeof-perf
WORKDIR /root/nvmeof-perf
RUN git init && \
    git remote add origin https://github.com/Eideticom/nvmeof-perf.git
RUN git fetch origin
RUN git checkout -b nvmeof-perf e5c79708

# Install p2pmem-test. We pull a tag for this like we do for other
# things to ensure a consistent environment.

WORKDIR /root
RUN git clone https://github.com/sbates130272/p2pmem-test.git
WORKDIR /root/p2pmem-test
RUN git checkout -b p2pmem 64978e09
RUN git submodule init
RUN git submodule update
RUN make
RUN cp p2pmem-test /usr/local/bin

# Install fio. We don't pull it from the package because we want a
# good up to date version and we want it configured for us with things
# like the rdma ioengine.

WORKDIR /root
WORKDIR /root/fio
RUN git init
RUN git remote add axboe https://github.com/axboe/fio.git
RUN git remote add bates https://github.com/sbates130272/fio.git
RUN git fetch axboe && git fetch bates
RUN git checkout -b fio fio-3.5
RUN ./configure
RUN make
RUN make install

# Install SPDK and DPDK. These are important for user-space NVMe and
# NVMe-oF. We copy the setup.sh script and a simple NVMe HelloWorld
# program into the path. Note that SPDK currently does not support
# non-x86 ARCH so we pull the code but skip the install for those.

WORKDIR /root/spdk
RUN git init
RUN git remote add origin https://github.com/spdk/spdk.git
RUN git fetch origin
RUN git checkout -b spdk v17.10.1
RUN git submodule update --init

RUN apt-get update && apt-get install -y \
    libcunit1-dev \
    libssl-dev \
    libnuma-dev \
    uuid-dev

RUN ./configure --with-rdma
RUN if [ "$(uname -m)" = x86_64 ]; then make; fi

RUN if [ "$(uname -m)" = x86_64 ]; then  cp ./scripts/setup.sh \
    ./examples/nvme/hello_world/hello_world /usr/local/bin; fi

# Copy in the required tools in the tools subfolder and either install
# or place them in a suitable place as required. NB a few of these
# tools are x86_64 specific and will obvioulsy bork if you are running
# a differnet ARCH.

COPY tools/rdma/mlxup /usr/local/bin
COPY tools/rdma/ibdev2netdev /usr/local/bin
COPY tools/rdma/offload /usr/local/bin

COPY tools/net/parav_loopback /usr/local/bin

COPY tools/nvmeof/server/server-gui /usr/local/bin
COPY tools/nvmeof/server/setup_nvmet /usr/local/bin
COPY tools/nvmeof/server/unsetup_nvmet /usr/local/bin

COPY tools/nvmeof/client/connect /usr/local/bin

# Now perform some Broadcom NetExtreme specific steps. This includes
# installing some tools. Note that for these RNICs to work we need
# certain BRCM drivers and the upstream version is not always the ones
# you need (e.g. bnxt_en and bnxt_re). Note that the brcm_counters
# script will only work on upstream kernel at 4.14 or newer...

COPY tools/rdma/bnxtnvm /usr/local/bin

# Install the counter script. Note that the Broadcom counters will
# only work on upstream kernel at 4.14 or newer... 

COPY tools/rdma/counters /usr/local/bin

# Install the rebind-nvme script which is useful to changing the
# module parameters on a NVMe SSD.

COPY tools/nvme/rebind-nvme /usr/local/bin

# Copy a tmux based script so we can setup windows nicely inside the
# docker container.

COPY tools/tmux/run-tmux /usr/local/bin

# Update the pciids file so we pull in the Eideticom VID and DID
# information.

RUN update-pciids

# Now add a local user called rdma-user so we don't have to execute things
# as root inside the container. We give this user sudo rights with no
# password requirements.

RUN useradd -ms /bin/bash rdma-user
RUN echo "rdma-user:rdma" | chpasswd
RUN echo "rdma-user ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers

# Copy the fio scripts into a fio folder for the rdma-user

WORKDIR /home/rdma-user
RUN mkdir fio
COPY tools/nvmeof/client/*.fio /home/rdma-user/fio/
COPY tools/rdma/*.fio /home/rdma-user/fio/

# Copy the commands file, which contains some handy cut and pastes
# into the home folder of the new user.

COPY misc/commands /home/rdma-user

# Now switch to our new user and switch the working folder to their
# home folder so we are ready to be attached too.

WORKDIR /home/rdma-user
USER rdma-user
