#!/bin/bash

# Copyright 2012 Joachim Breitner
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


# Script to put the zpub documentation into a zpub instance, or update it.

set -e

ZPUB_PATHS="${ZPUB_PATHS:=path-files/zpub-paths-tmp}"

if ! [ -r "$ZPUB_PATHS" ]
then
  echo "Cannot read file $ZPUB_PATHS in variable \$ZPUB_PATHS"
  exit 1
fi

. $ZPUB_PATHS

USAGE="Usage:

$0 name

where
 name:            Directory name of the instance in $ZPUB_INSTANCES
"

CUST="$1"

if [ -z "$CUST" ]
then
  echo "$USAGE"
  exit 1
fi

if [ ! -d "$ZPUB_INSTANCES/$CUST" ]
then
  echo "ERROR: $ZPUB_INSTANCES/$CUST does not exist."
  exit 1
fi

co="$ZPUB_INSTANCES/$CUST/repos/source-checkout" 

if [ -d "$co" ]
then
	rm -rf "$co"
fi

svn co "file://$ZPUB_INSTANCES/$CUST/repos/source" "$co"

for docdir in $ZPUB_SHARED/docs/*
do
	docname=$(basename $docdir)
	# This can be switched to the logic in 3f9597488efc0bfff923241506753b4adcebd832
	# once we do not have to support subversion before 1.7
	if [ -e "$co/$docname" ]
	then
		svn rm "$co/$docname"
	fi

	rsync -r "$docdir"/ "$co/$docname" 
	svn add "$co/$docname"
	svn propset svn:keywords Id "$co/$docname"/*.xml
done

svn ci -m "Importing zpub documentation for version $ZPUB_VERSION" $co
rm -rf $co
