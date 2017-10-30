# Dockerfile for user-space RMDA/NVMe-oF Development

## Introduction

This repo contains the Dockerfile and assocaited other files to
download, install and run the RDMA userspace code and some associated
NVMe over Fabrics code.

## Building the Docker image

Run

`docker build -t rdma:latest .`

in the top-level folder of this repo on a machine with docker
installed. You can obviously change the tag to whatever works best for
you but the run script (see below) will only use the image tags
provided too it.

## Running the Docker image

Run

`docker run -i -t rdma:latest`

to jump into an interactive session on the container. However this
container will be limited by a few things:

1. The image will not have access to the the /dev/* nodes needed to
establish and run RDMA.

2. Not all the kernel modules on the host may be loaded so we may not
have access to certain things needed to run RMDA.

To overcome these issues use the run-rdma script.

## The run-rdma script

The run-rdma script is the preferred way to lauch the container. It
performs a bunch of checks and prep work and then launches the
container based on the provded image. Check the comments in the this
script for more information on the options.

There are currently a couple of issues that need to be addressed.

1. The parav_loopback script sets up some network rules and those are
stored inside kernel space. Therefore they persist across Docker
container spin-ups (but not reboots). Ideally we will add a check for
this in run-rdma.

2. A similar thing happens in the configfs tree regarding the
configuration of the NVMe-oF target. Running the target setup from
inside the container places entitries in kernel space which persiste
across container spin-ups (but not reboots). Again we should probably
handle this in run-rdma before we spin up the container.

3. And a similar thing happens again on the NVMe-oF host (initiator)
side as a new /dev/nvmeXnY entry is made when a NVMe-oF connection is
made and this resides in kernel space. Again we should check for this
in the run-rdma script.

Once you get into the container you probably want to do some of the
following (but being aware of issues 1 and 2 above).

1. Configure the parav_loopback to avoid the kernel just performing
loopback in the kernel (or boucing traffic off one RNIC). You are
almost certainly going to want to pass non-default arguments into this
script if you are running it outside of Eideticom's yoda machine.

2. Configure the NVMe-oF target. Right now we use setup_nvmet to do
this though we plan to move to nvmetcli soon. Again your arguments
will almost certainly not want to be the defaults. Again this may
already be done in a prior spin up of the container. Note unset_nvmet
should clear this back to its original state.

3. Configure the NVMe-F host. Run the connect script to do this. Again
the defaults probably won't work for you and this may have persisted
from a previous run.

4. Run the server-gui script to get some cool tmux based panes with
different things in them (like htop and the Microsemi PCIe switch
ncurses GUI). Note this is optional.

5. You probably want to check that you have a fabrics based NVMe
device by doing nvme list and checking a fabrics device exists. Let's
assume we see one at /dev/nvme1n1.

6. Try some fio runs (e.g. fio --filename=/dev/nvme1n1
fio/randboth.fio). There are a bunch of pre-written fio scripts in the
fio subfolder for your amusment.

7. You can try some RDMA perftest runs (e.g. ib_write_bw) by running
something like ib_write_bw -x 1 -D 60 -d mlx5_0 on the server window
and ib_write_bw -x 1 -D 60 -d mlx5_1 172.18.1.1 on the client side. If
you want to test p2pmem try adding a --mmap /dev/p2pmem0 on the server
side. Of course your device names and IP addresses may differ to
mine. Of course p2pmem only works if you have a p2pmem kernel and a
p2pmem device in your system.

8. For the fabrics target try adding P2PMEM=yes to the setup_nvmet
call to enable it.

## The tools subfolder

The tools subfolder containers a number of useful userspace tools that
tend to be vendor specific. We put them here so they can be run on the
host or copied into the container as needed.

## The misc subfolder

The misc folder contains a range of fun things including:

1. 70-persistent-net.rules - an example udev rules file for giving the
network interfaces in the system sane names.

## Notes for Mellanox CX5s

The CX5s are well supported by the upstream drivers. For RoCE mode you
need to use the user space tools to set the physical layer to
Ethernet. You can use configfs to set the preferred RoCE mode. Note
you should see two GID entries per IP address (one is RoCEv1 and the
other is RoCEv2).

## Notes for Broadcom NetExtremes

Even if the FW is up to date, the RoCE needs to be turned on using the
ldiag tool (which requires a horrible out-of-tree kernel module to be
loaded). Right now we are being asked to use the BRCM provided drivers
(bnxt_en and bnxt_re) rather than the in-tree versions of these
drivers. However if one is using the upstream user-space code (which
this Docker container does) the one MUST use the upstreamed version of
bnxt and bnxt_re to get an ABI match.

Note that when connecting the 25Gbps dual port NetExtremes to the
Stingray using the 4:1 cable you should use cable "A" to connect to
one of the ports of the 25Gbps device. Use ethtool -s <dev> speed
25000 to set the speed and also disable autoneg.
