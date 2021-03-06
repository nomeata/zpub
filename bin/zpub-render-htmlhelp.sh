#!/bin/bash

# Copyright 2010 Joachim Breitner
# 
# Licensed under the EUPL, Version 1.1 or – as soon they will be approved
# by the European Commission – subsequent versions of the EUPL (the
# "Licence"); you may not use this work except in compliance with the
# Licence.
# You may obtain a copy of the Licence at:
# 
# http://ec.europa.eu/idabc/eupl
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the Licence is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# Licence for the specific language governing permissions and limitations
# under the Licence.


# Script to render a the htmlhelp format of a zpub document

# Expects to be run in an output directory containing subdirectories source and
# style. 

set -e

ZPUB_PATHS="${ZPUB_PATHS:=path-files/zpub-paths-tmp}"

if ! [ -r "$ZPUB_PATHS" ]
then
  echo "Cannot read file $ZPUB_PATHS in variable \$ZPUB_PATHS"
  exit 1
fi

. $ZPUB_PATHS


echo "Running $(basename $0)..."

if [ ! -d style -o ! -d source ]
then
  echo "This script needs to be run the output directory, and expects"
  echo "subdirectories source and style"
  exit 1
fi

cd "source"
DOCNAME="$(basename *.xml .xml)"

if [ ! -r "$DOCNAME.xml" ]
then
  echo "Could not find document source ($DOCNAME)"
  exit 1
fi
cd ..

outdir="htmlhelp-temp"
test -d "$outdir"|| mkdir -p "$outdir"
cd "$outdir"

STYLESHEET=""
for path in ../style/htmlhelp/htmlhelp.xsl ../style/htmlhelp.xsl
do
  if [ -e "$path" ]
  then
    STYLESHEET="$path"
    echo "Using stylesheet $path"
    break
  fi
done 

if [ -z "$STYLESHEET" ]
then
  echo "No stylesheet found at ../style/htmlhelp/htmlhelp.xsl"
  exit 1
fi

xsltproc --xinclude                                     \
	 --stringparam img.src.path images/             \
	 --stringparam keep.relative.image.uris 0       \
         --stringparam htmlhelp.chm "$DOCNAME.chm"	\
	 --stringparam htmlhelp.hpc "$DOCNAME.hpc"	\
	 --stringparam htmlhelp.hhk "$DOCNAME.hhk"	\
	  $STYLESHEET ../source/"$DOCNAME.xml"

if [ -d "../style/htmlhelp/static" ]
then
	echo "Copying style media files from ../style/htmlhelp/static"
	rsync --copy-links --recursive --exclude='.*' --itemize-changes ../style/htmlhelp/static/ .
fi

echo "Copying document media files"
xsltproc --html $ZPUB_SHARED/data/htmldepend.xsl *.html |sort -u |
while read imgpath
do
	if [ -e "$imgpath" ]; then  continue; fi
	# first check if the file is already here (probably because it part of
	# the style media files)

	origpath="$(echo "$imgpath" | cut -d/ -f2-)"
	mkdir -p "$(dirname "$(realpath -m -s "$imgpath")")"
	cp -v "$(realpath -m -s "../source/$origpath")" "$(realpath -m -s "$imgpath")"
done

HHC="$(find "$(winepath C:)" -name hhc.exe)"
echo -n "Expecting hhc.exe at $HHC "
test -e "$HHC"
echo "found."
wine "$HHC" htmlhelp.hhp || true

test -e "$DOCNAME.chm" && find ! -name "$DOCNAME.chm" -delete
mv "$DOCNAME.chm" ../
cd ..
rmdir "$outdir"

echo "$(basename $0) is done."
