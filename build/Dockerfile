FROM archlinux:latest

ENV OUTPUT_DIR /output

RUN \
	pacman --noconfirm -Syy && \
	pacman --noconfirm -S arch-install-scripts zsh sudo zip parted

WORKDIR /workdir