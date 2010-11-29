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


# Script to render a the HTML format of a zpub document

# Expects to be run in an output directory containing subdirectories source and
# style. 

set -e

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

outdir="${DOCNAME}_html"
test -d "$outdir"|| mkdir -p "$outdir"
cd "$outdir"

xsltproc ../style/html.xsl ../source/"$DOCNAME.xml"

mkdir -p images style
cp -fl /usr/share/xml/docbook/stylesheet/nwalsh/images/callouts/*.png style/
test -d ../style/html-shared && rsync -r ../style/html-shared/ .
test -d ../source/images/ && rsync -r ../source/images/ images/
rm -f ../${DOCNAME}_html.zip
zip -r ../${DOCNAME}_html.zip .

