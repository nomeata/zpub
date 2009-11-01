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
# This is the zpub post-commit hook.
# It will see what customer has created the change, what documents are changed
# and create appropriate zpub spooler jobs.
#

ZPUB=/opt/zpub

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
CUST=${CUST/#"$ZPUB"\/}
echo "Determined customer $CUST"

if [ ! -d "$ZPUB/$CUST" ]
then
  echo "ERROR: $ZPUB/$CUST is not a directory" >&2
  exit 1
fi

STYLE=$(cat $ZPUB/$CUST/conf/default_style)
if [ ! -d "$ZPUB/$CUST/style/$STYLE" ]
then
  echo "Could not find style directory in $ZPUB/$CUST/style/$STYLE"  >&2
  exit 1
fi


svnlook -r $REV changed "$REPOS" |grep '^[AU]'|cut -c 5-|cut -d/ -f1|sort -u|
while read DOC
do
  JOBNAME="$(date "+%Y%m%d-%H%M%S-$$-$DOC.job"|tr -c A-Za-z0-9_\\n- _)"
  cat > /opt/zpub/spool/new/"$JOBNAME" <<__END__
$CUST
$REV
$DOC
$STYLE
$ZPUB/$CUST/output/$DOC/archive/$REV/$STYLE
__END__
  mv /opt/zpub/spool/new/"$JOBNAME" /opt/zpub/spool/todo/"$JOBNAME"
done

