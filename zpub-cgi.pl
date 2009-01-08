#!/usr/bin/perl

use strict;
use warnings;

# Constants
my $ZPUB = '/opt/zpub';

# Global vars
our ($CUST,$tt,$q);

# Modules
use Template;
use Template::Constants qw( :debug );
use File::Basename qw/dirname basename/;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use File::stat;
use Time::localtime;



############################
# Data Retrieval functions #
############################

# Returns a list of all documents of the customer
sub collect_documents {
    my @ret;
    for (glob "$ZPUB/$CUST/output/*") {
	push @ret, basename($_) if -d;
    } 
    return @ret;
}


# Returns a list of all documents of the customer
sub collect_revisions {
    my ($doc) = @_;
    
    my @ret;
    for (glob "$ZPUB/$CUST/output/$doc/archive/*") {
	if (-d $_) {
	    if (m!$ZPUB/$CUST/output/$doc/archive/(\d+)-(.*)!) {
		push @ret, [$1,$2];
	    } else {
		die "Unmatchable file: $_";
	    }
	}
    } 
    return @ret;
}

# Selects the latest revision from a list of revisions
sub select_latest {
    my @revs = @_;

    my $ret;
    for my $rev (@revs) {
	if (not defined $ret or $rev->[0] > $ret->[0]) {
	    $ret = $rev;
	}
    }
    return $ret;
}

sub revpath {
    my ($doc,$rev) = @_;
    return "$ZPUB/$CUST/output/$doc/archive/".$rev->[0]."-".$rev->[1];
}

# Information about the files in a given revision of
# a document
sub collect_output {
    my ($doc,$rev) = @_;

    my $path = revpath($doc,$rev);

    my @ret;
    for my $file (glob "$path/*") {
	my $filename = basename($file);
	my $type;
	if      ($filename =~ /\.chm$/) {
	    $type = 'chm';
	} elsif ($filename =~ /\.pdf$/) {
	    $type = 'pdf';
	} elsif ($filename =~ /_html\.zip$/) {
	    $type = 'html-zip';
	} elsif ($filename =~ /_html$/ and -d $file) {
	    $type = 'html-dir';
	} else {
	    # Ignoring file (probably a log file or something)
	    next;
	}

	my $size;
	if (-d $file) {$size = 'directory';}
        else          {$size = -s $file;}

	my $date = ctime(stat($file)->mtime);

	my $url = sprintf "/%s/archive/%d-%s/%s", $doc,@$rev,$filename;
	
	push @ret, {
	    filename => $filename,	
	    type => $type,	
	    size => $size,
	    date => $date,
	    url => $url,
	};
    }
    return \@ret;
}

####################
# Output functions #
####################

sub standard_vars {
    return ( cust => $CUST );   
}

# All documents for one customer
sub show_documents {
    $tt->process('show_documents.tt', {
	standard_vars(),
	documents => [ collect_documents() ]
    }) or die ("Error: ".$tt->error());
}

# Overview about a document
sub show_overview {
    my ($doc) = @_;
    
    my @revs = collect_revisions($doc);

    my $rev = select_latest(@revs);

    my $files = collect_output($doc, $rev);

    $tt->process('show_overview.tt', {
	standard_vars(),
	doc => $doc,
	revs => [ @revs ],
	this_rev => $rev,
	files => $files,
    }) or die ("Error: ".$tt->error());
}
    

################
# Main routine #
################

# Set up CGI
$q = new CGI;


# Figure out what customer we are working for
$CUST = $q->param('cust') or die 'Missing parameter "cust"\n';

# Set up headers
print $q->header(-type=>'text/html', -charset=>'utf-8');

# Set up TT
$tt = Template->new({
    INCLUDE_PATH => "$ZPUB/templates",
    DEBUG => DEBUG_UNDEF,
}) || die "$Template::ERROR\n";

# Figure out what page to show
unless (defined $q->param('doc')) {
    # Show doc list
    show_documents()
} else {
    
    # Show information about a specific document
    my $doc = $q->param('doc');    
    
    unless (-d "$ZPUB/$CUST/output/$doc") {
	die "Document $doc does not exist.\n";
    }

    unless (defined $q->param('rev')) {
	# No specific revision requested, print overview page
	show_overview($doc);
    } else {
	die 'Requested page unknown'
    }
}
