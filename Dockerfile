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
    apt-utils \
    autoconf \
    build-essential \
    cmake \
    dh-make \
    dh-systemd \
    ethtool \
    emacs24-nox \
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
    net-tools \
    ninja-build \
    pciutils \
    pkg-config \
    python \
    python-docutils \
    valgrind \
    strace \
    sudo \
    sysstat \
    tmux \
    traceroute \
    vim \
    wget

# Install mstflint. Note the Ubuntu Xenial version is not recent
# enough to support CX5 so we copy in a more recent release. We might
# want to change this down the road. Note that this .deb was edited to
# remove the libumad5 dependency since inifiband-diags now provides
# that.

WORKDIR /root
COPY tools/rdma/mstflint_4.6.0-1_amd64.deb .
RUN dpkg -i mstflint_4.6.0-1_amd64.deb

# Install the switchtec-user and nvmetcli cli program via github. This
# is because  we don't have packages for them yet. Also install
# nvme-cli via GitHub as the packaged version does not at this time
# support fabrics.

WORKDIR /root
RUN git clone https://github.com/Microsemi/switchtec-user.git
WORKDIR /root/switchtec-user
RUN git checkout -b switchtec v0.7
RUN make install

WORKDIR /root
RUN git clone git://git.infradead.org/users/hch/nvmetcli.git

WORKDIR /root
RUN git clone https://github.com/linux-nvme/nvme-cli.git
WORKDIR /root/nvme-cli
RUN git checkout -b nvme-cli v1.4
RUN make
RUN make install

# Install p2pmem-test. We pull a tag for this like we do for other
# things to ensure a consistent environment.

WORKDIR /root
RUN git clone https://github.com/sbates130272/p2pmem-test.git
WORKDIR /root/p2pmem-test
RUN git checkout -b p2pmem v1.0
RUN git submodule init
RUN git submodule update
RUN make
RUN cp p2pmem-test /usr/local/bin

# Install fio. We don't pull it from the package because we want a
# good up to date version and we want it configured for us with things
# like the rdma ioengine.

WORKDIR /root
RUN git clone https://github.com/axboe/fio.git
WORKDIR /root/fio
RUN git checkout -b fio fio-3.1
RUN ./configure
RUN make
RUN make install

# Copy in the required tools in the tools subfolder and either install
# or place them in a suitable place as required. NB some of these
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

# Add the broadcom specific user-space. We need this for now to get
# the 100G NICs working in user-space. We got these instructions from
# Broadcom on Oct 31st 2017. With luck these can be reverted to
# upstream in time. Note this kills other RNIC vendors code.

RUN apt-get update && apt-get install -y \
    libibverbs-dev \
    ibverbs-utils \
    librdmacm1 \
    rdmacm-utils \
    infiniband-diags \
    perftest

WORKDIR /root
RUN mkdir -p brcm
WORKDIR /root/brcm
COPY tools/brcm/libbnxt_re-20.8.0.6.tar.gz /root/brcm
RUN tar xvfz libbnxt_re-20.8.0.6.tar.gz
WORKDIR /root/brcm/libbnxt_re-20.8.0.6/
RUN sh autogen.sh
RUN ./configure --sysconfdir=/etc
RUN make
RUN make install all
RUN cp src/.libs/libbnxt_re*.so /usr/lib/x86_64-linux-gnu/


#TBD: Get kernel modules to build. For now we assume user has already
#done this.
#
#RUN apt-get update && apt-get install -y \
#    kernel-package
#
#WORKDIR /root/brcm
#COPY tools/brcm/netxtreme-bnxt_en-1.8.26.tar.gz /root/brcm
#RUN tar xvfz netxtreme-bnxt_en-1.8.26.tar.gz
#WORKDIR /root/brcm/netxtreme-bnxt_en-1.8.26
#RUN make

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

# Copy the commands file, which contains some handy cut and pastes
# into the home folder of the new user.

COPY misc/commands /home/rdma-user

# Now switch to our new user and switch the working folder to their
# home folder so we are ready to be attached too.

WORKDIR /home/rdma-user
USER rdma-user
