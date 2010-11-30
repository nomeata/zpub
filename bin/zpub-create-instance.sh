#!/bin/bash

# Copyright 2009,2010 Joachim Breitner
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


# Script to create a new zpub instance

set -e

function tell () { echo "$@"; "$@"; }
function tell_cat () { echo "Writing $1"; cat > "$1"; }

ZPUB_PATHS="${ZPUB_PATHS:=path-files/zpub-paths-tmp}"

if ! [ -r "$ZPUB_PATHS" ]
then
  echo "Cannot read file $ZPUB_PATHS in variable \$ZPUB_PATHS"
  exit 1
fi

. $ZPUB_PATHS

if ! getent passwd "$ZPUB_USER" >/dev/null 
then
  echo "User $ZPUB_USER (defined in \$ZPUB_USER) does not exist"
  exit 1
fi

if ! getent group "$ZPUB_GROUP" >/dev/null 
then
  echo "User $ZPUB_GROUP (defined in \$ZPUB_GROUP) does not exist"
  exit 1
fi

USAGE="Usage:

$0 name 'Full Name' zpub.domain.com

where
 name:            Directory name of the instance in $ZPUB_INSTANCES
 'Full Name':     Name as shown in the web interface
 zpub.domain.com: Hostname for this virtual host
"

CUST="$1"
NAME="$2"
HOSTNAME="$3"

if [ -z "$CUST" -o -z "$NAME" -o -z "$HOSTNAME" ]
then
  echo "$USAGE"
  exit 1
fi

if [ "$CUST" = "demo" ]
then
  echo "WARNING: The instance demo is reserved for read-only demonstrational instances!"
fi

if [ -d "$ZPUB_INSTANCES/$CUST" ]
then
  echo "ERROR: $ZPUB_INSTANCES/$CUST already exists."
  exit 1
fi

mkdir -vp "$ZPUB_INSTANCES"/"$CUST"/{conf,output,repos,settings/{final_rev,subscribers},style}

echo "Creating files in $ZPUB_INSTANCES/$CUST/conf/..."
echo "$NAME" | tell_cat "$ZPUB_INSTANCES/$CUST"/conf/cust_name
echo final_approve | tell_cat "$ZPUB_INSTANCES/$CUST"/conf/features
echo '' | tell_cat "$ZPUB_INSTANCES/$CUST"/conf/admins
echo plain | tell_cat "$ZPUB_INSTANCES/$CUST"/conf/default_style
echo plain | tell_cat "$ZPUB_INSTANCES/$CUST"/conf/final_style
tell_cat "$ZPUB_INSTANCES/$CUST"/conf/formats <<__END__
html
pdf
#htmlhelp
__END__

echo "Symlinking plain style to $ZPUB_INSTANCES/$CUST/style/plain"
ln -vs "$ZPUB_SHARED/styles/plain" "$ZPUB_INSTANCES/$CUST/style/plain"

echo "Creating files in $ZPUB_INSTANCES/$CUST/settings/..."
echo -n | tell_cat "$ZPUB_INSTANCES/$CUST"/settings/htpasswd

tell_cat "$ZPUB_INSTANCES/$CUST/conf/apache.conf" <<__END__ 
<VirtualHost *:80>
	ServerAdmin root@$HOSTNAME
	ServerName $HOSTNAME
	RedirectPermanent / https://$HOSTNAME/
</VirtualHost>

<VirtualHost *:443>
	ServerAdmin root@$HOSTNAME
	ServerName $HOSTNAME
	DocumentRoot $ZPUB_INSTANCES/$CUST/output

	Include $ZPUB_ETC/apache-ssl.conf

	# For logfiles
	<Files *.log>
		AddDefaultCharset utf-8 
	</Files>

	RewriteEngine On
	RewriteRule ^/$				$ZPUB_BIN/zpub-cgi.pl?cust=test [L]
	RewriteRule ^/status/$			$ZPUB_BIN/zpub-cgi.pl?cust=test&status= [L]
	RewriteRule ^/admin/passwd/$		$ZPUB_BIN/zpub-cgi.pl?cust=test&admin=passwd [L]
	RewriteRule ^/([^/]*)/$ 		$ZPUB_BIN/zpub-cgi.pl?cust=test&doc=\$1 [L]
	RewriteRule ^/([^/]*)/archive/$		$ZPUB_BIN/zpub-cgi.pl?cust=test&doc=\$1&archive= [L]
	RewriteRule ^/([^/]*)/archive/(\d+)/$	$ZPUB_BIN/zpub-cgi.pl?cust=test&doc=\$1&rev=\$2 [L]
	RewriteRule ^/([^/]*)/subscribers/$	$ZPUB_BIN/zpub-cgi.pl?cust=test&doc=\$1&subscribers= [L]

	<Directory $ZPUB_BIN/zpub-cgi.pl>
		SetHandler cgi-script
		Options +ExecCGI

		AuthType Basic
		AuthName "zpub-Installation $NAME"
		AuthUserFile $ZPUB_INSTANCES/$CUST/settings/htpasswd
	        Require valid-user
	</Directory>

	Alias /static $ZPUB_SHARED/templates/static
	<Directory $ZPUB_SHARED/templates/static>
		Options FollowSymLinks
		AllowOverride None
		Order allow,deny
		allow from all

		AuthType Basic
		AuthName "Demo zpub-Installation"
		AuthUserFile $ZPUB_INSTANCES/$CUST/settings/htpasswd
	        Require valid-user
	</Directory>

	<Directory $ZPUB_INSTANCES/$CUST/output/>
		Options Indexes FollowSymLinks
		AllowOverride None
		Order allow,deny
		allow from all

		AuthType Basic
		AuthName "Demo zpub-Installation"
		AuthUserFile $ZPUB_INSTANCES/$CUST/settings/htpasswd
	        Require valid-user
	</Directory>

 	<Location /svn>
 		DAV svn
 		SVNPath $ZPUB_INSTANCES/$CUST/repos/source
 
 		AuthType Basic
 		AuthName "Demo zpub-Installation"
 		AuthUserFile $ZPUB_INSTANCES/$CUST/settings/htpasswd
		Require valid-user
 	</Location>
</VirtualHost>
__END__

echo "Symlinking apache configuration at $ZPUB_ETC/apache.conf.d/$CUST.conf"
ln -sv "$ZPUB_INSTANCES/$CUST/conf/apache.conf" "$ZPUB_ETC/apache.conf.d/$CUST.conf" 


echo "Creating source SVN repository..."
tell svnadmin create "$ZPUB_INSTANCES/$CUST/repos/source"
mkdir -v "$ZPUB_INSTANCES/$CUST/repos/source/dav"
ln -svf "$ZPUB_BIN/zpub-post-commit-hook.sh" "$ZPUB_INSTANCES/$CUST/repos/source/hooks/post-commit"

echo "Making settings and output directories and svn repository owned by and"
echo "writable for group $ZPUB_GROUP."
chgrp -c -R "$ZPUB_GROUP" "$ZPUB_INSTANCES/$CUST/settings" "$ZPUB_INSTANCES/$CUST/output" \
            "$ZPUB_INSTANCES/$CUST/repos/source/"{db,dav}
chmod -c -R g+w "$ZPUB_INSTANCES/$CUST/settings" "$ZPUB_INSTANCES/$CUST/output" \
                "$ZPUB_INSTANCES/$CUST/repos/source/"{db,dav}

echo
echo \
'Instance fully created. You still need to fill the style directory, add user
names to the htpasswd file and the admins file and enable the apache configuration.'
