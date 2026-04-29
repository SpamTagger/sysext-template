#!/usr/bin/env bash
# vim: set ts=2 sw=2 expandtab :
set -euo pipefail

PKG=$(jq -r .package metadata.json)
COMP=$(jq -r .component metadata.json)
ARCH=( $(jq -r '.architectures[]' metadata.json) )
DIST=( $(jq -r '.dists[]' metadata.json) )
REPO=$(jq -r .repository metadata.json)

LAST_TAG=$(curl -L https://api.github.com/repos/${REPO#*github.com/}/releases 2>/dev/null | jq -r 'sort_by(.updated_at)|[last]|.[0]|.name' 2>/dev/null)
if [[ "$LAST_TAG" == 'null' ]]; then
  echo "No tags. Generate first release." >&2
  echo "REBUILD=true"
  exit 0
fi
CURRENT=$(curl -L ${REPO}/releases/download/${LAST_TAG}/release.json 2>/dev/null)

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
    if [[ "$(echo $CURRENT | jq -r '.package_versions|[.'${dist}'_'${arch}'][0]')" != "$VERSION" ]]; then
      echo "Updates Needed" >&2
      echo "REBUILD=true"
      exit 0
    fi
  done
done

echo "Up-to-date" >&2
echo "REBUILD=false"
exit 0
