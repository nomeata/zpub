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

#
# zpub spooler. Perodically looks in $ZPUB_SPOOL for new zpub rendering jobs.
# The files in that directory are create in $ZPUB_SPOOL/new and then moved to
# $ZPUB_SPOOL/todo. When they are in use, they are moved to $ZPUB_SPOOL/wip and
# finally deleted or moved to $ZPUB_SPOOL/fail. They have a file ending of ".job"
#
# The format of the .job files is one argument to zpub-render.sh per line.

ZPUB_PATHS="${ZPUB_PATHS:=path-files/zpub-paths-tmp}"

if ! [ -r "$ZPUB_PATHS" ]
then
  echo "Cannot read file $ZPUB_PATHS in variable \$ZPUB_PATHS"
  exit 1
fi

. $ZPUB_PATHS

for dir in "$ZPUB_SPOOL/todo" "$ZPUB_SPOOL/wip" "$ZPUB_SPOOL/fail";
do
  if [ ! -d "$dir" ]
  then
    echo "$dir is not a directory or missing."
    exit 1
  fi
done

while sleep 1
do
  FILE=$(cd $ZPUB_SPOOL/todo/; ls|head -n 1)
  if [ ! -z "$FILE" ]
  then
    mv "$ZPUB_SPOOL/todo/$FILE" "$ZPUB_SPOOL/wip/$FILE" || continue
    echo "Found job $FILE to work on."
    
    {
      read -r CUST
      read -r REV
      read -r DOC
      read -r STYLE
    } < "$ZPUB_SPOOL/wip/$FILE" 

    echo "Parameters:"
    echo " CUST: $CUST"
    echo " REV: $REV"
    echo " DOC: $DOC"
    echo " STYLE: $STYLE"

    if
      $ZPUB_BIN/zpub-render.sh "$CUST" "$REV" "$DOC" "$STYLE"
    then
      echo "zpub-render.sh returned ok, job finished"
      rm -f "$ZPUB_SPOOL/wip/$FILE"
    else
      echo "zpub-render.sh failed, job moved to spool/fail"
      mv "$ZPUB_SPOOL/wip/$FILE" "$ZPUB_SPOOL/fail/$FILE"
    fi
    $ZPUB_BIN/zpub-send-mail.pl "$CUST" "$REV" "$DOC" "$STYLE"
    $ZPUB_BIN/zpub-link-latest.pl "$CUST" "$REV" "$DOC" "$STYLE"
  fi
done
