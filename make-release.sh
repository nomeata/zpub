#!/bin/bash

if [ -z "$1" ]
then
	echo "Usage: $0 upstream-version"
	exit 1
fi

git archive \
	--prefix "zpub-$1/" \
	--format tar \
	HEAD |
	tar --delete "zpub-$1/debian" |
	gzip -9 >  "../zpub_$1.orig.tar.gz" \

