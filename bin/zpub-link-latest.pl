#!/usr/bin/perl

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


# Script to update the "latest" link
# $ zpub-send-mail.pl $CUST $REV $DOC $STYLE $OUTDIR
# 
# where (same as zpub-render.sh)
#  $CUST:   Basename of the customers directory in $ZPUB_INSTANCES/
#  $REV:    SVN-Revision to render
#  $DOC:    Document to render (subdirectory of repository)
#  $STYLE:  Style to use (subdirectory of $ZPUB_INSTANCES/CUST/style/$STLYE

use strict;
use warnings;

# Constants
our ($ZPUB_PERLLIB,$ZPUB_INSTANCES);
BEGIN {
my $paths='Set by zpub-install.sh'
require $paths;
}


# Modules
use Template;
use Template::Constants qw( :debug );

use lib $ZPUB_PERLLIB;
use ZPub;


our ($CUST,$revn,$doc,$style) = @ARGV;

if ( not $CUST or not $revn or not $doc or not $style )
{
	die "Parameter list to $0 not complete\n";
}

my @revisions = collect_revisions($doc);
my $rev = select_latest_ok(@revisions);

if ($rev) {
	printf "Adding symlink to revision %d.\n", $rev->{revn};
	my $to = sprintf "$ZPUB_INSTANCES/$CUST/output/%s/archive/%d", $doc,$rev->{revn};
	my $from = sprintf "$ZPUB_INSTANCES/$CUST/output/%s/latest", $doc,$rev->{revn};

	if  (-l $from) {
		unlink $from or die "Could not remove old symlink $from\n";
	}
	symlink $to, $from or die "Could not symlink $from -> $to: $!\n";
} else {
	print "No good latest revision found"
}
