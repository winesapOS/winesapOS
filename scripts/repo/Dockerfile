FROM archlinux:latest
#FROM manjarolinux/base:latest

RUN pacman -S -y -y -u --noconfirm && \
  pacman -S --noconfirm --needed base-devel curl git python-setuptools python-setuptools-scm sudo && \
  echo -e '[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf && \
  pacman -S -y && \
  sed -i s'/\[options\]/\[options\]\nXferCommand = \/usr\/bin\/curl --connect-timeout 60 --retry 10 --retry-delay 5 -L -C - -f -o %o %u/'g /etc/pacman.conf && \
  useradd --create-home winesap && \
  chown -R winesap:winesap /home/winesap && \
  echo "winesap ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/winesap && \
  chmod 0440 /etc/sudoers.d/winesap
# Clean.
RUN pacman --noconfirm -S -c -c && rm -rf /var/cache/pacman/pkg/*

COPY winesapos-build-repo.sh /usr/local/bin/

VOLUME ["/output"]

# The 'makepkg' command requires building packages as a non-root user.
# Use the 'winesap' user.
USER winesap:winesap
WORKDIR /home/winesap
CMD /usr/local/bin/winesapos-build-repo.sh
