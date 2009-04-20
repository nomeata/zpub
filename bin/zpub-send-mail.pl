#!/usr/bin/perl

# Script to mail commit information 
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

my $subscribers = read_subscribers($doc);
unless ($subscribers) {exit 0;}

my $tt = Template->new({
    INCLUDE_PATH => "$ZPUB/templates",
    DEBUG => DEBUG_UNDEF,
    POST_CHOMP => 1,
}) || die "$Template::ERROR\n";


my @revs = collect_revisions($doc);
my $this_revs = select_revs($revn, @revs);

my $vars = {
	cust     => $CUST,
        doc       => $doc,
        revs      => \@revs,
        this_revs => $this_revs,
	};

my $body;
$tt->process('mail_notification.tt', $vars, \$body) or die ("Error: ".$tt->error());

my $msg = MIME::Lite->new(
        From     => 'notifications@zpub.de',
        To       => $subscribers,
        Subject  => "Changes to document $doc",
        Data     => $body
    );
$msg->attr('content-type.charset' => 'UTF-8');

$msg->send() or die "Could not send mail.\n";
