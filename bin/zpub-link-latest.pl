#!/usr/bin/perl

# Script to update the "latest" link
# $ zpub-send-mail.pl $CUST $REV $DOC $STYLE $OUTDIR
# 
# where (same as zpub-render.sh)
#  $CUST:   Basename of the customers directory in $ZPUB/
#  $REV:    SVN-Revision to render
#  $DOC:    Document to render (subdirectory of repository)
#  $STYLE:  Style to use (subdirectory of $ZPUB/CUST/style/$STLYE
#  $OUTDIR: Directory to write to (will be created)

use strict;
use warnings;

# Constants
our $ZPUB;
BEGIN { $ZPUB = '/opt/zpub'; }

# Modules
use Template;
use Template::Constants qw( :debug );

use MIME::Lite;

use lib "$ZPUB/bin/lib";
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
	my $to = sprintf "$ZPUB/$CUST/output/%s/archive/%d", $doc,$rev->{revn};
	my $from = sprintf "$ZPUB/$CUST/output/%s/latest", $doc,$rev->{revn};

	if  (-l $from) {
		unlink $from or die "Could not remove old symlink $from\n";
	}
	symlink $to, $from or die "Could not symlink $from -> $to: $!\n";
} else {
	print "No good latest revision found"
}
