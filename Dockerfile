FROM archlinux:latest

ENV OUTPUT_DIR /output

RUN \
	pacman --noconfirm -Syy && \
	pacman --noconfirm -Syu && \
	pacman --noconfirm -S arch-install-scripts

ADD . /workdir

WORKDIR /workdir