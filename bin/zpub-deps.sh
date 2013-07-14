#!/bin/bash

# Copyright 2013 Joachim Breitner
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


# Creates a list of dependencies of the given document

USAGE='
$ zpub-deps.sh $CUST $REV $DOC

where
 $CUST:   Basename of the customers directory in $ZPUB_INSTANCES/
 $REV:    SVN-Revision to render
 $DOC:    Document to render (subdirectory of repository)
'

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

if [ -z "$CUST" -o -z "$REV" -o -z "$DOC" ]
then
  echo "Parameter list not complete."
  echo "$USAGE"
  exit 1
fi

DEPS="$ZPUB_INSTANCES/$CUST/cache/deps"

if [ ! -d "$DEPS" ]
then
    echo "Creating directory $DEPS"
    mkdir "$DEPS"
fi

test -d "$DEPS"

if [ -r "$DEPS/$DOC.rev" ]
then
    oldrev="$(cat "$DEPS/$DOC.rev")"
    if [ "$oldrev" -gt "$REV" ]
    then
        echo "Not updating dependency information, as information for newer revision $oldrev is available."
        exit 0
    fi
fi

echo "Updating $DEPS/$DOC."
xsltproc "$ZPUB_SHARED/data/xmldepend.xsl" source/*.xml |
    grep '^\.\./common/' |
    cut -c 11- > "$DEPS/$DOC.tmp"
mv "$DEPS/$DOC.tmp" "$DEPS/$DOC"
echo $REV > "$DEPS/$DOC.rev"
echo "Done updating $DEPS/$DOC, revision $REV."

