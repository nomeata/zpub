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


# Script to render a the PDF output of a zpub document

# Expects to be run in an output directory containing subdirectories source and
# style. 

set -e

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

STYLESHEET=""
for path in style/pdf/fo.xsl style/fo.xsl
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
  echo "No stylesheet found at style/pdf/fo.xsl"
  exit 1
fi


xsltproc $STYLESHEET source/"$DOCNAME.xml" > source/"$DOCNAME.fo"
fopopts=""
test -e "style/fop.xconf" && fopopts="-c style/fop.xconf"
test -e "style/pdf/fop.xconf" && fopopts="-c style/pdf/fop.xconf"
fop $fopopts -fo source/"$DOCNAME.fo" -pdf "$DOCNAME.pdf"
rm source/"$DOCNAME.fo"

echo "$(basename $0) is done."
