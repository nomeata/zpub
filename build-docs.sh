#!/bin/bash -e

# zpub installation script

usage="$0 destdir/
This file is to be called from the extracted zpub sources or the git
repository. As a parameter, it expects a directory (that does not have to exist).
It build the zpub documentation found in docs/ into that directory, both as PDF
and html files. It uses the style found in plain/.

It is recommended to not use the destdir/ in other ways, as this script might
delete existing files (e.g. if they are called source, style or *.zip)

This script is targetted for users who need to build the documentation outside
of a running zpub instance, e.g. for the zpub webpage or for distribution
packages. End users are encouraged to build the documentation in their zpub
instance.
"

destdir="$1"

if [ -z "$destdir" ]
then
  echo "$usage"
  exit 1
fi


# Version number
if [ -r VERSION ]
then
	VERSION="$(cat VERSION)"
else
	VERSION="$(git describe --tags)"
fi

zpubdir=$PWD

[ -d $destdir ] || mkdir -p $destdir
rm -f "$destdir/style"
ln -s $zpubdir/styles/plain "$destdir/style"

./install.sh path-files/zpub-paths-tmp

for doc in docs/*
do
	[ -d "$doc" ] || continue;

	docname=$(basename $doc)
	rm -rf "$destdir/source"
	cp -r "$doc" "$destdir/source"

	(
		cd "$destdir"
		sed -i 's/\$Id\$/\&zpub;-Version '"$VERSION"'/' source/*.xml
		$zpubdir/bin/zpub-render-html.sh
		rm *.zip
		$zpubdir/bin/zpub-render-pdf.sh
	)
	rm -rf "$destdir/source"
done

rm "$destdir/style"
