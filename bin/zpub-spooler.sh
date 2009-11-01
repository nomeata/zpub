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
# zpub spooler. Perodically looks in $ZPUB/spool for new zpub rendering jobs.
# The files in that directory are create in $ZPUB/spool/new and then moved to
# $ZPUB/spool/todo. When they are in use, they are moved to $ZPUB/spool/wip and
# finally deleted or moved to $ZPUB/spool/fail. They have a file ending of ".job"
#
# The format of the .job files is one argument to zpub-render.sh per line.

ZPUB=/opt/zpub

for dir in "$ZPUB/spool/todo" "$ZPUB/spool/wip" "$ZPUB/spool/fail";
do
  if [ ! -d "$dir" ]
  then
    echo "$dir is not a directory or missing."
    exit 1
  fi
done

while sleep 1
do
  FILE=$(cd $ZPUB/spool/todo/; ls|head -n 1)
  if [ ! -z "$FILE" ]
  then
    mv "$ZPUB/spool/todo/$FILE" "$ZPUB/spool/wip/$FILE" || continue
    echo "Found job $FILE to work on."
    
    {
      read -r CUST
      read -r REV
      read -r DOC
      read -r STYLE
      read -r OUTDIR
    } < "$ZPUB/spool/wip/$FILE" 

    echo "Parameters:"
    echo " CUST: $CUST"
    echo " REV: $REV"
    echo " DOC: $DOC"
    echo " STYLE: $STYLE"
    echo " OUTDIR: $OUTDIR"

    if
      $ZPUB/bin/zpub-render.sh "$CUST" "$REV" "$DOC" "$STYLE" "$OUTDIR"
    then
      echo "zpub-render.sh returned ok, job finished"
      rm -f "$ZPUB/spool/wip/$FILE"
    else
      echo "zpub-render.sh failed, job moved to spool/fail"
      mv "$ZPUB/spool/wip/$FILE" "$ZPUB/spool/fail/$FILE"
    fi
    $ZPUB/bin/zpub-send-mail.pl "$CUST" "$REV" "$DOC" "$STYLE"
    $ZPUB/bin/zpub-link-latest.pl "$CUST" "$REV" "$DOC" "$STYLE"
  fi
done
