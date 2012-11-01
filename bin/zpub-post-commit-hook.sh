#!/bin/bash

# Copyright 2009,2010 Joachim Breitner
# 
# Licensed under the EUPL, Version 1.1 or -- as soon they will be approved
# by the European Commission -- subsequent versions of the EUPL (the
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
# This is the zpub post-commit hook.
# It will see what customer has created the change, what documents are changed
# and create appropriate zpub spooler jobs.
#

ZPUB_PATHS="${ZPUB_PATHS:=path-files/zpub-paths-tmp}"

if ! [ -r "$ZPUB_PATHS" ]
then
  echo "Cannot read file $ZPUB_PATHS in variable \$ZPUB_PATHS"
  exit 1
fi

. $ZPUB_PATHS


REPOS="$1"
REV="$2"

export LANG=de_DE.utf8

if [ -z "$REPOS" -o -z "$REV" ]
then
  echo "Unexpected arguments to $0: $*" >&2
  exit 1
fi

CUST="$REPOS"
CUST=${CUST/%\/repos\/source}
CUST=${CUST/#"$ZPUB_INSTANCES"\/}
echo "Determined customer $CUST"

if [ ! -d "$ZPUB_INSTANCES/$CUST" ]
then
  echo "ERROR: $ZPUB_INSTANCES/$CUST is not a directory" >&2
  exit 1
fi

for STYLE in $(cat $ZPUB_INSTANCES/$CUST/conf/default_style)
do
  if [ ! -d "$ZPUB_INSTANCES/$CUST/style/$STYLE" ]
  then
    echo "Could not find style directory in $ZPUB_INSTANCES/$CUST/style/$STYLE"  >&2
    exit 1
  fi
done

# The cache directory was introduced later; gracefully create it here.
mkdir -p $ZPUB_INSTANCES/$CUST/cache
svn ls -r $REV file://"$REPOS" | grep '/$' | cut -d/ -f1 | fgrep -x -v common > $ZPUB_INSTANCES/$CUST/cache/documents

svnlook -r $REV changed "$REPOS" |grep '^[AU]'|cut -c 5-|cut -d/ -f1|sort -u|
while read DOC
do
  if [ "$DOC" != common ]
  then
    for STYLE in $(cat $ZPUB_INSTANCES/$CUST/conf/default_style)
    do
      JOBNAME="$(date "+%Y%m%d-%H%M%S-$$-$DOC-$STYLE.job"|tr -c A-Za-z0-9_\\n- _)"
      cat > $ZPUB_SPOOL/new/"$JOBNAME" <<__END__
$CUST
$REV
$DOC
$STYLE
__END__
      mv $ZPUB_SPOOL/new/"$JOBNAME" $ZPUB_SPOOL/todo/"$JOBNAME"
    done
  fi
done
