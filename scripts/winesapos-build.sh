export \
    WINESAPOS_DEBUG_INSTALL=true \
    WINESAPOS_CREATE_DEVICE=true \
    WINESAPOS_BUILD_IN_VM_ONLY=false

bash scripts/winesapos-install.sh

## we need to introduce versioning here
ARCHIVE=winesapos.img.gz
gzip --keep --fast winesapos.img
mv winesapos.img.gz /workdir/output/
sha256sum /workdir/output/winesapos.img.gz > /workdir/output/winesapos-sha256sum.txt
