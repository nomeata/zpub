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
use SVN::SVNLook;

#############
# Utilities #
#############

sub lazy {
    my $func = shift;
    my @args = @_;
    my $ret = undef;
    return sub {
	$ret ||= $func->(@args);
	return $ret;
    }
}

############################
# Data Retrieval functions #
############################

# Returns a list of all documents of the customer
sub collect_documents {
    opendir(DIR, "$ZPUB/$CUST/output/") || die "can't opendir $ZPUB/$CUST/output/: $!";
    my @files = grep { (not /^\./) && -d "$ZPUB/$CUST/output/$_" } readdir(DIR);
    closedir DIR;
    return @files;
}

# Returns a list of all documents of the customer
# Each element has three 
sub collect_revisions {
    my ($doc) = @_;
    
    my @ret;
    opendir(DIR, "$ZPUB/$CUST/output/$doc/archive")
	|| die "can't opendir $ZPUB/$CUST/output/$doc/archive: $!";
    for (readdir(DIR)) {
	if (-d "$ZPUB/$CUST/output/$doc/archive/$_" && /(\d+)-(.*)/) {
	    push @ret, {revn => $1,
			style => $2,
			info => lazy(\&rev_info,$1)
			}
	}
    } 
    closedir DIR;
    return @ret;
}

# Selects the latest revision from a list of revisions
sub select_latest {
    my @revs = @_;

    my $ret;
    for my $rev (@revs) {
	if (not defined $ret or $rev->{revn} > $ret->{revn}) {
	    $ret = $rev;
	}
    }
    return $ret;
}

# Selects the given revision from a list of revisions
sub select_rev {
    my ($revn,@revs) = @_;

    my $ret;
    for my $rev (@revs) {
	if ($revn == $rev->{revn}) {
	    $ret = $rev;
	}
    }
    return $ret;
}

# Various pathnames
sub revpath {
    my ($doc,$rev) = @_;
    return "$ZPUB/$CUST/output/$doc/archive/".$rev->{revn}."-".$rev->{style};
}
sub repopath {
    return "$ZPUB/$CUST/repos/source";
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

	my $url = sprintf "/%s/archive/%d-%s/%s", $doc,$rev->{revn},$rev->{style},$filename;
	
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

# Given a revision number, returns the date, author and message
# in a hash
sub rev_info {
    my ($doc,$revn) = @_;

    my $look = SVN::SVNLook->new(repo => repopath(), cmd => '/usr/bin/svnlook');
    my ($author, $date, $log_msg) = $look->info(revision => $revn);
    return {date => $date,
            author => $author,
            log_msg => $log_msg}
}

# Gathers information about jobs in the spooler
sub collect_jobs {
    my %ret;
    
    for my $dir (qw/fail todo wip/) {
	$ret{$dir} = [];
	opendir(DIR, "$ZPUB/spool/$dir") || die "can't opendir $ZPUB/spool/$dir: $!";
	for (grep { (not /^\./) && -f "$ZPUB/spool/$dir/$_" } readdir(DIR)) {
	    open FILE, "$ZPUB/spool/$dir/$_" or die "can't open $ZPUB/spool/$dir/$_: $!";
	    chomp (my @lines = <FILE>);
	    close FILE;
	    my $cust = shift @lines;
	    next unless $cust eq $CUST;
	    push @{$ret{$dir}}, {
		jobname => $_,
		revn    => shift @lines,
		doc     => shift @lines,
		style   => shift @lines,
		outdir  => shift @lines,
	    };
	    die "Left over lines in job $_: @lines" if @lines;
	}
	closedir DIR;
    }
    return \%ret;
}

# Returns jobs that are newer than the given document/revision
sub newer_jobs {
    my ($doc,$rev) = @_;

    my $ret = collect_jobs();
    for my $jobs (values %$ret) {
	$jobs = [ grep { $_->{doc} eq $doc && $_->{revn} > $rev->{revn} } @$jobs ]
    }
    return $ret;
}


####################
# Output functions #
####################

sub standard_vars {
    return (
	cust => $CUST,
	doc  => 0,
     );   
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

    my $newer_jobs = newer_jobs($doc,$rev);

    $tt->process('show_overview.tt', {
	standard_vars(),
	doc => $doc,
	revs => [ @revs ],
	this_rev => $rev,
	files => $files,
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

    my $rev = select_rev($revn, @revs);
    
    my $files = collect_output($doc, $rev);

    $tt->process('show_archived_rev.tt', {
	standard_vars(),
	doc      => $doc,
	revs     => \@revs,
	this_rev => $rev,
	files    => $files,
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
if (defined $q->param('doc')) {
    # Show information about a specific document
    my $doc = $q->param('doc');    
    
    unless (-d "$ZPUB/$CUST/output/$doc") {
	die "Document $doc does not exist.\n";
    }

    if (defined $q->param('archive')) { 
	show_archive($doc);    
    } elsif (defined $q->param('rev'))  {
	my $rev = $q->param('rev');
	show_archived_rev($doc, $rev);
    } else {
	# No specific revision requested, print overview page
	show_overview($doc);
    }
} elsif (defined $q->param('status')) {
    # System status
    show_status()
} else {
    # Show doc list
    show_documents()
}
    
