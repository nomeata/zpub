#!/bin/bash

# Copyright 2009 Joachim Breitner
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


# Script to render a specific revision of a document

USAGE='
$ zpub-render.sh $CUST $REV $DOC $STYLE

where
 $CUST:   Basename of the customers directory in $ZPUB_INSTANCES/
 $REV:    SVN-Revision to render
 $DOC:    Document to render (subdirectory of repository)
 $STYLE:  Style to use (subdirectory of $ZPUB_INSTANCES/CUST/style/$STLYE
'

# validate!:
# xmllint  --noout --xinclude  --postvalid xml-file.xml

set -e

ZPUB_PATHS="${ZPUB_PATHS:=path-files/zpub-paths-tmp}"

if ! [ -r "$ZPUB_PATHS" ]
then
  echo "Cannot read file $ZPUB_PATHS in variable \$ZPUB_PATHS"
  exit 1
fi

. $ZPUB_PATHS

CUST="$1"
REV="$2"
DOC="$3"
STYLE="$4"
OUTDIR="$ZPUB_INSTANCES/$CUST/output/$DOC/archive/$REV/$STYLE"

if [ -z "$CUST" -o -z "$REV" -o -z "$DOC" -o -z "$STYLE" ]
then
  echo "Parameter list not complete."
  echo "$USAGE"
  exit 1
fi

for dir in "$ZPUB_INSTANCES/$CUST" "$ZPUB_INSTANCES/$CUST/style/$STYLE" "$ZPUB_INSTANCES/$CUST/repos/source";
do
  if [ ! -d "$dir" ]
  then
    echo "$dir is not a directory."
    exit 1
  fi
done

# These are set here, and not in zpub-render-html.sh, to keep the latter script
# independent of a full zpub installation.
export SP_ENCODING=utf-8
export FOP_HYPHENATION_PATH=$ZPUB_SHARED/tools/fop-hyph.jar

# Create and enter output directory
test -d "$OUTDIR"  || mkdir -p "$OUTDIR"
cd "$OUTDIR"

# Redirect output to logfile
echo $$ > zpub-render-in-progress
exec &> >(tee zpub-render.log)


test -L "style" && rm -f "style"
ln -s $ZPUB_INSTANCES/$CUST/style/$STYLE style

test -d "source" && rm -rf "source"
echo "Exporting sources to $OUTDIR/source"
svn export -r $REV "file://$ZPUB_INSTANCES/$CUST/repos/source/$DOC" source

while read format 
do
  if [ -n "$format" -a "${format:0:1}" != "#" ]
  then
    if [ -x "$ZPUB_BIN/zpub-render-$format.sh" ]
    then
      "$ZPUB_BIN/zpub-render-$format.sh" 
    else
      echo "ERROR: No renderer for format $format found!"
      exit 1
    fi
  fi
done < "$ZPUB_INSTANCES/$CUST/conf/formats"

cd "$OUTDIR"
echo "Successfully generated output, deleting source directory"
rm -rf "$OUTDIR/source"
rm -f  "$OUTDIR/style"
rm -f zpub-render-in-progress
