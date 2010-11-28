#!/bin/bash -e

# zpub installation script

usage="$0 <zpub-paths>
This file is to be called from the extracted zpub sources or the git
repository. As a parameter, it expects a file specifying the ZPUB paths. An
environment variable of DESTDIR may be set and is prepended to all paths. "

paths="$1"
shift

if ! [ -e "$paths" ]
then
  echo "$usage"
  exit 1
fi

. $paths

function tell () { echo "$@"; "$@"; }

dirs="ZPUB_ETC ZPUB_BIN ZPUB_PERLLIB ZPUB_SHARED ZPUB_INSTANCES ZPUB_SPOOL"

for var in $dirs
do
  if [ -z "${!var}" ]
  then
    echo "$var not defined. Path file broken?"
    exit 1
  fi
done

for var in $dirs
do
  mkdir -pv "${!var}"
done

# Copy files
cp -v bin/*.sh bin/*.pl -t "$DESTDIR""$ZPUB_BIN"
chmod -c +x "$DESTDIR""$ZPUB_BIN"/*.sh "$DESTDIR""$ZPUB_BIN"/*.pl
cp -rva bin/lib/* -t "$DESTDIR""$ZPUB_PERLLIB"
cp -rva templates -t "$DESTDIR""$ZPUB_SHARED"
mkdir -vp "$DESTDIR""$ZPUB_SPOOL"/{todo,wip,fail,new}

# Create shell paths file
paths_shell="$ZPUB_SHARED/paths.sh"
cp -v "$paths" "$DESTDIR""$paths_shell"

# Create perl paths file
paths_perl="$ZPUB_SHARED/paths.pl"
(
  echo '# zpub path configuration file for perl programs'
  for var in $dirs
  do
    echo "our \$$var;"
    echo "BEGIN { \$$var = '${!var}'};"
  done
  echo '1;'
) > "$DESTDIR""$paths_perl"

tell perl -i -p -e 's!^ZPUB_PATHS=.*!ZPUB_PATHS="'"$paths_shell"'"!;' "$DESTDIR""$ZPUB_BIN"/*.sh
tell perl -i -p -e 's!^my \$paths=.*!my \$paths="'"$paths_perl"'";!;' "$DESTDIR""$ZPUB_BIN"/*.pl


