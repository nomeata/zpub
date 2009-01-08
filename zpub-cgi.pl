#!/usr/bin/perl

use strict;
use warnings;

# Constants
my $ZPUB = '/opt/zpub';

# Global vars
our ($CUST,$tt,$q);

# Modules
use Template;
use CGI;
use CGI::Carp qw(fatalsToBrowser);


############################
# Data Retrieval functions #
############################

# Returns a list of all documents of the customer
sub collect_documents {
    my @ret;
    
    for (glob "$ZPUB/$CUST/output/*") {
	if (-d $_) {
	    if (m!$ZPUB/$CUST/output/(.*)!) {
		push @ret, $1;
	    } else {
		die "Unmatchable file: $_";
	    }
	}
    } 
    return @ret;
}

####################
# Output functions #
####################

sub standard_vars {
    return ( cust => $CUST );   
}

sub show_documents {
    $tt->process('show_documents.tt', {
	standard_vars(),
	documents => [ collect_documents() ]
    })
    || die ("Error: ".$tt->error());
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
}) || die "$Template::ERROR\n";

# Figure out what page to show
unless (defined $q->param('doc')) {
    # Show doc list
    show_documents()
} else {
    # TODO
}
