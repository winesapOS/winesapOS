FROM archlinux:latest

ENV OUTPUT_DIR /output

# 	pacman --noconfirm -Syu && \

RUN \
	pacman --noconfirm -Syy && \
	pacman --noconfirm -S arch-install-scripts zsh sudo

ADD . /workdir

WORKDIR /workdir