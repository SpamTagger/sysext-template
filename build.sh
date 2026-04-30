#!/usr/bin/env bash
# vim: set ts=2 sw=2 expandtab :
set -euo pipefail

NAME=$(jq -r .name metadata.json)
PKG=$(jq -r .package metadata.json)
COMP=$(jq -r .component metadata.json)
ARCH=( $(jq -r '.architectures[]' metadata.json) )
DIST=( $(jq -r '.dists[]' metadata.json) )
REPO=$(jq -r .repository metadata.json)

[[ -d build ]] || mkdir -p build
[[ -d output ]] && rm -rf output
mkdir -p output

for dist in ${DIST[@]}; do
  [[ $dist == 'trixie' ]] && DEB_VER=13
  [[ $dist == 'forky' ]] && DEB_VER=14
  [[ $dist == 'duke' ]] && DEB_VER=15
  for arch in ${ARCH[@]}; do

cat > build/podman_build.sh <<'EOF'
set -euo pipefail

WORK=/tmp/sysext
mkdir -p "$WORK"
cd "$WORK"

apt-get update

DEBIAN_FRONTEND=noninteractive apt-get install -y squashfs-tools

# In case we ever add this package to the base image, the build should fail and we should consider dropping this extension.
if dpkg -s "$PKG" >/dev/null 2>&1; then
  echo "ERROR: Package '$PKG' already exists in base image"
  exit 1
fi

# record installed packages before
dpkg-query -W -f='${Package}\n' | sort > before.txt

# install target package + deps
DEBIAN_FRONTEND=noninteractive apt-get install -y "$PKG"

# record installed packages after
dpkg-query -W -f='${Package}\n' | sort > after.txt

# determine newly added packages
comm -13 before.txt after.txt > newpkgs.txt

# always include requested package
grep -qx "$PKG" newpkgs.txt || echo "$PKG" >> newpkgs.txt

mkdir rootfs

# collect files from all new packages
while read -r pkgname; do
  dpkg -L "$pkgname" | while read -r file; do
    [[ -e "$file" ]] || continue
    [[ -d "$file" ]] && continue

    mkdir -p "rootfs$(dirname "$file")"
    cp -a --parents "$file" rootfs/
  done
done < newpkgs.txt

# extension metadata
mkdir -p rootfs/usr/lib/extension-release.d

VERSION=$(dpkg-query -W -f='${Version}' "$PKG")

cat > rootfs/usr/lib/extension-release.d/extension-release.$NAME <<META
ID=debian
VERSION_ID=$DEB_VER
NAME=$NAME
PACKAGE=$PKG
PACKAGE_VERSION=$VERSION
ARCH=$ARCH
VERSION_CODENAME=$DIST
BUILD_TIME=$(date +%Y-%m-%dT%H:%M:%S)
REPOSITORY=$REPO
META

cp rootfs/usr/lib/extension-release.d/extension-release.$NAME \
  /output/${NAME}_${DIST}_${ARCH}.manifest

mksquashfs rootfs \
  /output/${NAME}_${DIST}_${ARCH}.squashfs \
  -comp zstd -no-progress >/dev/null
EOF
chmod +x build/podman_build.sh
    podman run \
      --arch "$arch" \
      -v "$PWD/output:/output:Z" \
      -v "$PWD/build:/build:Z" \
      -e NAME="$NAME" \
      -e PKG="$PKG" \
      -e DIST="$DIST" \
      -e DEB_VER="$DEB_VER" \
      -e ARCH="$arch" \
      -e REPO="$REPO" \
      ghcr.io/spamtagger/spamtagger-bootc:spamtagger-$DEB_VER \
      bash -x -c '/build/podman_build.sh'
  done
done

rm -rf build
