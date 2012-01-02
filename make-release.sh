#!/bin/bash

set -e

if [ -z "$1" ]
then
	echo "Usage: $0 upstream-version"
	exit 1
fi

git describe --tags > VERSION
git archive \
	--prefix "zpub-$1/" \
	--format tar \
	HEAD |
	tar --delete "zpub-$1/debian" \
	>  "../zpub_$1.orig.tar" 
tar --file ../zpub_$1.orig.tar --append VERSION --transform "s,^,zpub-$1/," 
gzip -9 --force "../zpub_$1.orig.tar" 
rm VERSION
