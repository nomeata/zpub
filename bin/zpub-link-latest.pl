#!/usr/bin/perl

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


our ($CUST,$revn,$doc,$argstyle) = @ARGV;

if ( not $CUST or not $revn or not $doc or not $argstyle )
{
	die "Parameter list to $0 not complete\n";
}

my $latestpath = sprintf "$ZPUB_INSTANCES/$CUST/output/%s/latest", $doc;
if (-l $latestpath) {
	print "Removing old-style latest link\n";
	unlink $latestpath;
}
unless (-d $latestpath) {
	print "Creating directory $latestpath\n";
	mkdir $latestpath;
}

my @revisions = collect_revisions($doc);
my @styles = collect_styles(@revisions);
for my $style (@styles) {
	my @stylerevs = select_with_style($style, \@revisions);
	my $rev = select_latest_ok(@stylerevs);
	if ($rev) {
		printf "Adding symlink to revision %d for style %s.\n", $rev->{revn}, $style;
		my $to = sprintf "$ZPUB_INSTANCES/$CUST/output/%s/archive/%d/%s", $doc,$rev->{revn}, $style;
		my $from = sprintf "$ZPUB_INSTANCES/$CUST/output/%s/latest/%s", $doc, $style;

		if  (-l $from) {
			unlink $from or die "Could not remove old symlink $from\n";
		}
		symlink $to, $from or die "Could not symlink $from -> $to: $!\n";
	} else {
		printf "No good latest revision for style %s found\n", $style;
	}
}
