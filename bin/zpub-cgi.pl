#!/usr/bin/perl

use strict;
use warnings;

# Constants
our $ZPUB;
BEGIN { $ZPUB = '/opt/zpub'; }

# Global vars
our ($CUST,$USER,%SETTINGS,$tt,$q);

# Modules
use Template;
use Template::Constants qw( :debug );
use File::Basename qw/dirname basename/;
use File::Slurp;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
$CGI::POST_MAX=1024 * 100;  # max 100K posts
$CGI::DISABLE_UPLOADS = 1;  # no uploads
use File::stat;
use Time::localtime;
use SVN::SVNLook;
use DateTime;


use lib "$ZPUB/bin/lib";
use ZPub;

####################
# Output functions #
####################

sub standard_vars {
    return (
	cust     => $CUST,
	doc      => 0,
	admin    => is_admin(),
	settings => \%SETTINGS,
	documents => [ collect_documents() ],
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

    my $rev = select_latest(@revs);

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

    $tt->process('show_archive.tt', {
	standard_vars(),
	doc => $doc,
	revs => [ @revs ],
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

    $tt->process('show_status.tt', {
	standard_vars(),
	jobs	 => $jobs,
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
sub show_subscribers_edit {
    my ($doc) = @_;
    my $subscribers = read_subscribers($doc);
    $tt->process('show_subscribers_edit.tt', {
	standard_vars(),
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

    queue_job($revn,$doc,$SETTINGS{final_style});

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

    my $jobname = DateTime->now->strftime("%Y%m%d-%H%M%S-$$.job");

    write_file("$ZPUB/spool/new/$jobname",
	(sprintf "%s\n%s\n%s\n%s\n%s\n", $CUST,$revn, $doc, $style, $outdir)) 
	or die "Could not write to $ZPUB/spool/new/$jobname: $!\n";

    rename("$ZPUB/spool/new/$jobname","$ZPUB/spool/todo/$jobname")
	or die "Could not move job $ZPUB/spool/new/$jobname to $ZPUB/spool/todo/$jobname: $!\n";

}

sub do_retry {
    my ($jobname) = @_;

    rename("$ZPUB/spool/fail/$jobname","$ZPUB/spool/todo/$jobname")
	or die "Could not move job $ZPUB/spool/fail/$jobname to $ZPUB/spool/todo/$jobname: $!\n";
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
	
	unless (-d "$ZPUB/$CUST/output/$doc") {
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
    } else {
	die "Unknown POST target\n";
    }

    print $q->redirect($q->url(-absolute=>1));
    exit;
}

# Set up headers
print $q->header(-type=>'text/html', -charset=>'utf-8');

# Set up TT
$tt = Template->new({
    INCLUDE_PATH => "$ZPUB/templates",
    DEBUG => DEBUG_UNDEF,
}) || die "$Template::ERROR\n";

# Figure out what page to show
if (defined $q->url_param('doc')) {
    # Show information about a specific document
    my $doc = $q->url_param('doc');    
    
    unless (-d "$ZPUB/$CUST/output/$doc") {
	die "Document $doc does not exist.\n";
    }

    if (defined $q->url_param('archive')) { 
	show_archive($doc);    
    } elsif (defined $q->url_param('rev'))  {
	my $rev = $q->url_param('rev');
	show_archived_rev($doc, $rev);
    } elsif (defined $q->url_param('admin'))  {
	if ($q->url_param('admin') eq 'subscribers') {
	    # Subscribers Edit view
	    show_subscribers_edit($doc);
	} else {
	    die "Unknown admin command\n"
	}
    } else {
	# No specific revision requested, print overview page
	show_overview($doc);
    }
} elsif (defined $q->url_param('status')) {
    # System status
    show_status()
} elsif (defined $q->url_param('admin'))  {
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
    
