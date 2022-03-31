export \
    WINESAPOS_DEBUG_INSTALL=true \
    WINESAPOS_CREATE_DEVICE=true \
    WINESAPOS_BUILD_IN_VM_ONLY=false

zsh scripts/winesapos-install.sh

## we need to introduce versioning here
ARCHIVE=winesapos.img.gz
zip -s 1900m winesapos.img.zip winesapos.img
mv winesapos.img.zip /workdir/output/
sha512sum /workdir/output/winesapos-performance* > /workdir/output/winesapos-sha512sum.txt
