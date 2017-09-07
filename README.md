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

Add this..

## The tools subfolder

The tools subfolder containers a number of useful userspace tools that
tend to be vendor specific. We put them here so they can be run on the
host or copied into the container as needed.
