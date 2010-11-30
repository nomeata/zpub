#!/bin/bash -e

# zpub installation script

usage="$0 <zpub-paths>
This file is to be called from the extracted zpub sources or the git
repository. As a parameter, it expects a file specifying the ZPUB paths. An
environment variable of DESTDIR may be set and is prepended to all paths.
See INSTALL.en for more information."

paths="$1"

if ! [ -r "$paths" ]
then
  echo "$usage"
  exit 1
fi

shift

. $paths

function tell () { echo "$@"; "$@"; }
function tell_cat () { echo "Writing $1"; cat > "$1"; }

dirs="ZPUB_ETC ZPUB_BIN ZPUB_PERLLIB ZPUB_SHARED ZPUB_INSTANCES ZPUB_SPOOL"
users="ZPUB_USER"
groups="ZPUB_GROUP"

for var in $dirs $users $groups
do
  if [ -z "${!var}" ]
  then
    echo "$var not defined. Path file broken?"
    exit 1
  fi
done

for var in $dirs
do
  mkdir -pv "$DESTDIR""${!var}"
done

# Copy files
cp -v bin/*.sh bin/*.pl -t "$DESTDIR""$ZPUB_BIN"
chmod -c +x "$DESTDIR""$ZPUB_BIN"/*.sh "$DESTDIR""$ZPUB_BIN"/*.pl
cp -rva bin/lib/* -t "$DESTDIR""$ZPUB_PERLLIB"
cp -rva templates styles -t "$DESTDIR""$ZPUB_SHARED"
mkdir -vp "$DESTDIR""$ZPUB_SPOOL"/{todo,wip,fail,new}

# Create apache config
mkdir -vp "$DESTDIR""$ZPUB_ETC/apache.conf.d/"
tell_cat "$DESTDIR""$ZPUB_ETC/apache.conf.d/README" <<__END__
This directory contains symbolic links to the apache configuration files of
each zpub instance. When the instance is created with zpub-create-instance,
these are automatically generated 
__END__

tell_cat "$DESTDIR""$ZPUB_ETC/apache.conf" <<__END__
# Includes all zpub apache configuration files
Include $ZPUB_ETC/apache.conf.d/*.conf
__END__

tell_cat "$DESTDIR""$ZPUB_ETC/apache-ssl.conf" <<__END__
# This is the SSL configuration, as shared by all zpub instances
SSLEngine on
SSLCertificateFile    /etc/ssl/certs/ssl-cert-snakeoil.pem
SSLCertificateKeyFile /etc/ssl/private/ssl-cert-snakeoil.key
__END__


# Create shell paths file
paths_shell="$ZPUB_SHARED/paths.sh"
cp -v "$paths" "$DESTDIR""$paths_shell"

# Create perl paths file
paths_perl="$ZPUB_SHARED/paths.pl"
(
  echo '# zpub path configuration file for perl programs'
  for var in $dirs $users $groups
  do
    echo "our \$$var = '${!var}';"
  done
  echo '1;'
) > "$DESTDIR""$paths_perl"

tell perl -i -p -e 's!^ZPUB_PATHS=.*!ZPUB_PATHS="'"$paths_shell"'"!;' "$DESTDIR""$ZPUB_BIN"/*.sh
tell perl -i -p -e 's!^my \$paths=.*!my \$paths="'"$paths_perl"'";!;' "$DESTDIR""$ZPUB_BIN"/*.pl

echo "Installation finished. Make sure that $ZPUB_SPOOL is writeable by both
the webserver and the user $ZPUB_USER, e.g. by adding the webserver user to
group $ZPUB_GROUP, let this group own $ZPUB_SPOOL and make its subdirectories
group writeable."
