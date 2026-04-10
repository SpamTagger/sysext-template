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
  VERSION=$(
    curl -l https://ftp.debian.org/debian/dists/$dist/$COMP/source/Sources.gz 2>/dev/null |
    gunzip |
    grep -P "Package: $PKG\$" -A 10 |
    grep 'Version:' |
    cut -d' ' -f 2 |
    head -n 1
  )
  DIR=${PKG:0:3}
  if [[ $DIR == 'lib' ]]; then
    DIR=${PKG:0:4}
  else
    DIR=${PKG:0:1}
  fi
  for arch in ${ARCH[@]}; do
    curl -l https://deb.debian.org/debian/pool/$COMP/$DIR/$PKG/${PKG}_${VERSION}_${arch}.deb -o out.deb 2>/dev/null
    mkdir -p build
    cd build
    ar x ../out.deb
    tar -xf data.tar.xz
    rm control.tar.xz data.tar.xz debian-binary ../out.deb
    mkdir -p usr/lib/extension-release.d
    cat > usr/lib/extension-release.d/extension-release.$NAME <<EOF
ID=debian
VERSION_ID=$DEB_VER
NAME=$NAME
PACKAGE=$PKG
PACKAGE_VERSION=$VERSION
ARCH=$arch
VERSION_CODENAME=$dist
BUILD_TIME=$(date +%Y-%m-%dT%H:%M:%S)
REPOSITORY=$REPO
EOF
    cp usr/lib/extension-release.d/extension-release.$NAME ../output/${NAME}_${dist}_${arch}.manifest
    mksquashfs . ../output/${NAME}_${dist}_${arch}.squashfs -comp zstd -no-progress >/dev/null
    cd ..
  done
done

rm -rf build
