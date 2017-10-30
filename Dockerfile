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
    fio \
    gcc \
    git \
    htop \
    kmod \
    iputils-ping \
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
    wget \
    autoconf \
    build-essential \
    libpthread-stubs0-dev \
    libtool \
    libudev-dev \
    nasm

#ISA-L code
RUN git clone https://github.com/01org/isa-l.git
WORKDIR isa-l
RUN ./autogen.sh
RUN ./configure
RUN make
RUN make install

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
RUN git checkout -b rdma v15
WORKDIR /root
RUN tar cvfz rdma-core_15.orig.tar.gz rdma-core
WORKDIR /root/rdma-core
RUN dpkg-buildpackage -d
WORKDIR /root/
RUN dpkg -i --force-overwrite \
    rdma-core_15-1_amd64.deb \
    libibverbs1_15-1_amd64.deb \
    libibverbs-dev_15-1_amd64.deb \
    libibcm1_15-1_amd64.deb \
    ibverbs-utils_15-1_amd64.deb \
    ibverbs-providers_15-1_amd64.deb \
    rdmacm-utils_15-1_amd64.deb \
    librdmacm1_15-1_amd64.deb \
    librdmacm-dev_15-1_amd64.deb \
    libibumad3_15-1_amd64.deb \
    libibumad-dev_15-1_amd64.deb

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

# Copy in the perform python script which automates a pile of the
# perftest testing.

COPY tools/rdma/perform /usr/local/bin

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

# Now switch to our new user and switch the working folder to their
# home folder so we are ready to be attached too.

WORKDIR /home/rdma-user
USER rdma-user
