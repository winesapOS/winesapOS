#!/bin/bash

# this test will produce an image build from docker
# you could use the podman binary instead for testing

mkdir -p output
docker build --pull --no-cache -t winesapos-img-builder build/.
docker run --rm -v "$(pwd)":/workdir --privileged=true -i winesapos-img-builder:latest /bin/bash -x scripts/winesapos-build.sh
