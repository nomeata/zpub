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


use strict;
use warnings;


# Constants
our ($ZPUB_PERLLIB, $ZPUB_INSTANCES, $ZPUB_SHARED, $ZPUB_SPOOL, $ZPUB_VERSION);
BEGIN {
my $paths='Set by zpub-install.sh'
require $paths;
}

# We are german (and like UTF8)!
$ENV{LANG}="de_DE.utf8";


# Global vars
our ($CUST,$USER,%SETTINGS,$tt,$q);

# Modules
use Template;
use Template::Constants qw( :debug );
use IPC::Run qw/run/;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX=1024 * 100;  # max 100K posts
$CGI::DISABLE_UPLOADS = 1;  # no uploads

use lib $ZPUB_PERLLIB;
use Number::Bytes::Human qw(format_bytes);
use ZPub;
use VorKurzem;

####################
# Output functions #
####################

sub standard_vars {
    my $this_page = $q->script_name();
    # Strip a possible root path from the script name
    $this_page =~ s/^\Q$SETTINGS{rootpath}\E//;
    return (
	this_page=> $this_page,
	cust     => $CUST,
	doc      => 0,
	admin    => is_admin(),
	settings => \%SETTINGS,
	documents => [ collect_documents() ],
	zpub_version => $ZPUB_VERSION,
     );   
}

# All documents for one customer
sub show_documents {
    $tt->process('show_documents.tt', {
	standard_vars()
    }) or die ("Error: ".$tt->error());
}

# Overview about a document
sub show_overview {
    my ($doc) = @_;
    
    my @revs = collect_revisions($doc);

    my $rev = select_latest_ok(@revs) || '';

    my $final_rev = $SETTINGS{features}{final_approve} ? select_final($doc,@revs) : 0;

    my $newer_jobs = newer_jobs($doc,$rev);

    $tt->process('show_overview.tt', {
	standard_vars(),
	doc => $doc,
	revs => [ @revs ],
	this_rev => $rev,
	final_rev => $final_rev,
	newer_jobs => $newer_jobs,
    }) or die ("Error: ".$tt->error());
}

# Archive list
sub show_archive {
    my ($doc) = @_;

    my @revs = collect_revisions($doc);

    my $final_rev = $SETTINGS{features}{final_approve} ? select_final($doc,@revs) : 0;

    $tt->process('show_archive.tt', {
	standard_vars(),
	doc => $doc,
	revs => [ @revs ],
	final_rev => $final_rev,
    }) or die ("Error: ".$tt->error());
}

# Archived revision
sub show_archived_rev {
    my ($doc,$revn) = @_;

    my @revs = collect_revisions($doc);

    my $this_revs = select_revs($revn, @revs);
    
    $tt->process('show_archived_rev.tt', {
	standard_vars(),
	doc       => $doc,
	revs      => \@revs,
	this_revs => $this_revs,
    }) or die ("Error: ".$tt->error());
}

# Archived revision
sub show_status {
    my $jobs = collect_jobs();

    my $sysstatus = collect_sysstatus(); 

    $tt->process('show_status.tt', {
	standard_vars(),
	jobs	 => $jobs,
	sysstatus => $sysstatus,
    }) or die ("Error: ".$tt->error());
}

# Edit window for password editing
sub show_htpasswd_edit {
    my $htpasswd = read_htpasswd;
    $tt->process('show_htpasswd_edit.tt', {
	standard_vars(),
	htpasswd => $htpasswd,
    }) or die ("Error: ".$tt->error());
}

# Edit window for subscribers editing
sub show_subscribers {
    my ($doc) = @_;
    my $subscribers = read_subscribers($doc);
    $tt->process('show_subscribers.tt', {
	standard_vars(),
	doc => $doc,
	subscribers => $subscribers,
    }) or die ("Error: ".$tt->error());
}

###########
# Actions #
###########

# Edit window for password editing
sub do_htpasswd_edit {
    write_htpasswd($_[0]); 
}

# Mark a revision as approved
sub do_approve {
    my ($doc, $revn) = @_;

    write_doc_setting($doc,"final_rev",$revn);

    for my $style (@{$SETTINGS{final_style}}) {
        queue_job($revn,$doc,$style);
    }
}

# Set subscriber list
sub do_set_subscribers {
    my ($doc, $subscribers) = @_;

    write_doc_setting($doc,"subscribers",$subscribers);
}


# Queues a job, default output directory
sub queue_job {
    my ($revn, $doc, $style) = @_;
    
    my $outdir = revpath($doc, $revn, $style);

    my $jobname = DateTime->now->strftime("%Y%m%d-%H%M%S-$$-$style.job");

    write_file("$ZPUB_SPOOL/new/$jobname",
	(sprintf "%s\n%s\n%s\n%s\n%s\n", $CUST,$revn, $doc, $style, $outdir)) 
	or die "Could not write to $ZPUB_SPOOL/new/$jobname: $!\n";

    rename("$ZPUB_SPOOL/new/$jobname","$ZPUB_SPOOL/todo/$jobname")
	or die "Could not move job $ZPUB_SPOOL/new/$jobname to $ZPUB_SPOOL/todo/$jobname: $!\n";

}

sub do_retry {
    my ($jobname) = @_;

    die "Strange \$jobname: $jobname\n" unless $jobname =~ m/^[a-zA-Z0-9\._-]+$/;

    rename("$ZPUB_SPOOL/fail/$jobname","$ZPUB_SPOOL/todo/$jobname")
	or die "Could not move job $ZPUB_SPOOL/fail/$jobname to $ZPUB_SPOOL/todo/$jobname: $!\n";
}

sub do_remove_job {
    my ($state,$jobname) = @_;

    die "Strange \$state: $state\n" unless $state =~ m/^[a-z]+$/;
    die "Strange \$jobname: $jobname\n" unless $jobname =~ m/^[a-zA-Z0-9\._-]+$/;

    unlink("$ZPUB_SPOOL/$state/$jobname")
	or die "Could not delete job $ZPUB_SPOOL/$state/$jobname: $!\n";
}


################
# Main routine #
################

# Set up CGI
$q = new CGI;


# Figure out what customer we are working for
$CUST = $q->url_param('cust') or die 'Missing parameter "cust"'."\n";

# Figure out the current user
$USER = $q->remote_user();

# Read the settings
read_settings();

# Is this a POST?
if ($q->request_method() eq "POST") {
    if ($CUST eq "demo") { die "Modifications to the demo instance are prohibited.\n" }

    unless (is_admin()) { die "This action requires admin priviliges\n" }

    if (defined $q->param('set_htpasswd')) {
	if ($q->url_param('admin') eq 'passwd') {
	    if (not defined $q->param('htpasswd')) {
		die 'Missing parameter "htpasswd"'."\n";
	    }
	    do_htpasswd_edit($q->param('htpasswd'));
	} else {
	    die "Unknown POST target\n";
	}
    } elsif (defined $q->url_param('doc')) {
	my $doc = $q->url_param('doc');    
	
	unless (-d "$ZPUB_INSTANCES/$CUST/output/$doc") {
	    die "Document $doc does not exist.\n";
	}

	if (defined $q->param('approve')) {
	    if (not defined $q->param('revn')) {
		die 'Missing parameter "revn"'."\n";
	    }
	    do_approve($doc,$q->param('revn'));
	} elsif (defined $q->param('set_subscribers')) {
	    if (not defined $q->param('subscribers')) {
		die 'Missing parameter "subscribers"'."\n";
	    }
	    do_set_subscribers($doc,$q->param('subscribers'));
	} else {
	    die "Unknown POST target\n";
	}

    } elsif (defined $q->param('retry')) {
	if (not defined $q->param('jobname')) {
	    die 'Missing parameter "jobname"'."\n";
	}
	do_retry($q->param('jobname'));
    } elsif (defined $q->param('remove')) {
	if (not defined $q->param('jobname')) {
	    die 'Missing parameter "jobname"'."\n";
	}
	if (not defined $q->param('state')) {
	    die 'Missing parameter "state"'."\n";
	}
	do_remove_job($q->param('state'),$q->param('jobname'));
    } else {
	die "Unknown POST target\n";
    }

    print $q->redirect($q->url(-absolute=>1));
    exit;
}

# Non-HTML-Pages here

if (defined $q->url_param('backup')) {
    unless (is_admin()) { die "You need admin priviliges to view this page.\n" };
    unless ($SETTINGS{features}{online_backup}) { die "The backup feature is not enabled.\n" };

    print $q->header(-type=>'application/x-gzip');
    run (['svnadmin', 'dump', '--quiet', repopath], '|', [ "gzip" ], \*STDOUT);
    exit;
}

# Set up headers
print $q->header(-type=>'text/html', -charset=>'utf-8');

# Set up TT
$tt = Template->new({
    INCLUDE_PATH => "$ZPUB_SHARED/templates",
    DEBUG => DEBUG_UNDEF,
}) || die "$Template::ERROR\n";

my $strp_relative = new VorKurzem;

$tt->context->define_vmethod('SCALAR','startswith',sub {
		my ($what,$with) = @_;
		return (substr ($what,0,length($with)) eq $with);
	});
$tt->context->define_vmethod('HASH','relative',sub {
		my ($what) = @_;
		return Encode::encode('utf8',$strp_relative->format_datetime($what));
	});
	

# Figure out what page to show
if (defined $q->url_param('doc')) {
    # Show information about a specific document
    my $doc = $q->url_param('doc');    
    
    unless (-d "$ZPUB_INSTANCES/$CUST/output/$doc") {
	die "Document $doc does not exist.\n";
    }

    if (defined $q->url_param('archive')) { 
	show_archive($doc);    
    } elsif (defined $q->url_param('rev'))  {
	my $rev = $q->url_param('rev');
	show_archived_rev($doc, $rev);
    } elsif (defined $q->url_param('subscribers'))  {
	# Subscribers Edit view
	show_subscribers($doc);
    } else {
	# No specific revision requested, print overview page
	show_overview($doc);
    }
} elsif (defined $q->url_param('status')) {
    # System status
    show_status()
} elsif (defined $q->url_param('admin'))  {
    unless (is_admin()) { die "You need admin priviliges to view this page.\n" };
    if ($q->url_param('admin') eq 'passwd') {
	# Passwd Edit view
	show_htpasswd_edit();
    } else {
	die "Unknown admin command\n"
    }
} else {
    # Show doc list
    show_documents()
}
