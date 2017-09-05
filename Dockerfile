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
# useful PCIe, NVMe and NVMe-oF packages.

RUN apt-get update && apt-get install -y \
    nvme-cli
    