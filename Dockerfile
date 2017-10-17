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
    fio \
    gcc \
    git \
    htop \
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
    git remote add origin https://github.com/linux-rdma/perftest.git
RUN git fetch origin
RUN git checkout -b perftest V4.1-0.2
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
RUN make install

WORKDIR /root
RUN git clone git://git.infradead.org/users/hch/nvmetcli.git

WORKDIR /root
RUN git clone https://github.com/linux-nvme/nvme-cli.git
WORKDIR /root/nvme-cli
RUN git checkout -b nvme-cli v1.4
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

# Copy the fio scripts into a fio folder.

WORKDIR /root
RUN mkdir fio
COPY tools/nvmeof/client/*.fio /root/fio/

# Now perform some Broadcom NetExtreme specific steps. This includes
# installing some tools. Note that for these RNICs to work we need
# certain BRCM drivers and the upstream version is not always the ones
# you need (e.g. bnxt_en and bnxt_re). Note that the brcm_counters
# script will only work on upstream kernel at 4.14 or newer...

COPY tools/rdma/bnxtnvm /usr/local/bin
COPY tools/rdma/brcm_counters /usr/local/bin

# Now add a local user called rdma-user so we don't have to execute things
# as root inside the container. We also create a rdma group so we can
# give the user access to H/W as needed.

RUN useradd -ms /bin/bash rdma-user
RUN echo "rdma-user:rdma" | chpasswd
RUN usermod -aG sudo rdma-user
USER rdma-user
WORKDIR /home/rdma-user
