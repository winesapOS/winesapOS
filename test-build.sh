#!/bin/bash

# this test will produce an image build from docker
# you could use the podman binary instead for testing

mkdir -p output
docker pull archlinux:latest
docker build --no-cache -t winesapos-img-builder .
docker run --rm -v $(pwd)/output:/workdir/output --privileged=true winesapos-img-builder:latest /bin/zsh -x scripts/winesapos-build.sh > 'build.log'