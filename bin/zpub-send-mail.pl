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


# Script to mail commit information 
# $ zpub-send-mail.pl $CUST $REV $DOC $STYLE
# 
# where (same as zpub-render.sh)
#  $CUST:   Basename of the customers directory in $ZPUB_INSTANCES/
#  $REV:    SVN-Revision to render
#  $DOC:    Document to render (subdirectory of repository)
#  $STYLE:  Style to use (subdirectory of $ZPUB_INSTANCES/$CUST/style/$STLYE

use strict;
use warnings;

# Constants
our ($ZPUB_PERLLIB, $ZPUB_SHARED, %SETTINGS);
BEGIN {
my $paths='Set by zpub-install.sh'
require $paths;
}

# Modules
use Template;
use Template::Constants qw( :debug );

use MIME::Lite;

use lib $ZPUB_PERLLIB;
use ZPub;


our ($CUST,$revn,$doc,$style) = @ARGV;

read_settings();

if ( not $CUST or not $revn or not $doc or not $style )
{
	die "Parameter list to $0 not complete\n";
}

my $subscribers = read_subscribers($doc);
unless ($subscribers) {exit 0;}

my $tt = Template->new({
    INCLUDE_PATH => "$ZPUB_SHARED/templates",
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
        settings => \%SETTINGS,
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
