# Dockerfile for user-space RMDA/NVMe-oF Development

## Introduction

This repo contains the Dockerfile and assocaited other files to
download, install and run the RDMA userspace code and some associated
NVMe over Fabrics code.

## Building the Docker image

Run

`docker build -t rdma:latest .`

in the top-level folder of this repo on a machine with docker
installed.

## Running the Docker image

Run

`docker run -i -t rdma:latest`

to jump into an interactive session on the container.