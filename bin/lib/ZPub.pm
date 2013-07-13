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

use warnings;

use strict;

our ($ZPUB_INSTANCES, $ZPUB_SPOOL);
our ($CUST,$USER,%SETTINGS);

use File::Basename qw/dirname basename/;
use File::Slurp;
use File::stat;
use Time::localtime;
use SVN::SVNLook;
use DateTime;
use DateTime::Format::Strptime;
use Filesys::Df;
use Sys::CpuLoad;
use File::Glob qw/:glob/;


use Number::Bytes::Human qw(format_bytes);

my $strp_absolute = new DateTime::Format::Strptime(
			pattern     => '%e. %B %Y um %H:%M',
			time_zone   => 'Europe/Berlin',
		);
my $strp_ctime = new DateTime::Format::Strptime(
			pattern     => '%a %b %d %T %Y',
			time_zone   => 'Europe/Berlin',
		);
my $strp_svn = new DateTime::Format::Strptime(
			pattern     => '%F %T %z',
#			on_error    => 'croak'
		);



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

sub to_hash {
    my %ret;
    $ret{$_} = 1 for @_;
    return \%ret;
}

############################
# Data Retrieval functions #
############################

# Returns a list of all documents of the customer
sub collect_documents {
    my (@files) = read_file("$ZPUB_INSTANCES/$CUST/cache/documents");
    chomp @files;
    return sort @files;
}

# Returns a list of all documents of the customer
sub collect_revisions {
    my ($doc) = @_;

    return unless -d "$ZPUB_INSTANCES/$CUST/output/$doc/archive";
    
    my @list;
    opendir(DIR, "$ZPUB_INSTANCES/$CUST/output/$doc/archive")
	|| die "can't opendir $ZPUB_INSTANCES/$CUST/output/$doc/archive: $!";
    for (readdir(DIR)) {
	if (-d "$ZPUB_INSTANCES/$CUST/output/$doc/archive/$_" && $_ =~ /^\d+$/){
	    my $revn = $_;
	    my %rev = (
		    revn => $revn,
		    info  => lazy(\&rev_info,$revn),
		    styles => [],
		    finished => 0,
	    );
	    opendir(SDIR, "$ZPUB_INSTANCES/$CUST/output/$doc/archive/$revn")
		|| die "can't opendir: $ZPUB_INSTANCES/$CUST/output/$doc/archive/$revn $!";
	    for (readdir(SDIR)) {
		if (-d "$ZPUB_INSTANCES/$CUST/output/$doc/archive/$revn/$_" && (substr $_,0,1) ne "."){
		    my $style = $_;
		    push @{$rev{styles}}, {
			style => $style,
			files => lazy(\&collect_output, $doc, $revn, $style),
		    };
		    if (! -e "$ZPUB_INSTANCES/$CUST/output/$doc/archive/$revn/$style/zpub-render-in-progress") {
			$rev{finished}++;
		    }
		}
	    }
	    closedir SDIR;
	    push @list, \%rev;
	}
    } 
    closedir DIR;
    return sort {$b->{revn} <=> $a->{revn}} @list;
}

# Collects all styles in these revisions
sub collect_styles {
    my @revs = @_;

    my %styles;
    for my $rev (@revs) {
	for my $style (@{$rev->{styles}}) {
	    $styles{$style->{style}} = 1;
	}
    }

    return keys %styles;
}

# Filters out the revs with a given style
sub select_with_style {
    my ($style,$revs) = @_;

    return grep {grep {$_->{"style"} eq $style} @{$_->{styles}}} @$revs;
}
    

# Selects the latest finished revision from a list of revisions
sub select_latest_ok {
    my @revs = @_;

    my $ret;
    for my $rev (@revs) {
	if ($rev->{finished} and (not defined $ret or $rev->{revn} > $ret->{revn})) {
	    $ret = $rev;
	}
    }
    return $ret;
}

# If final_approve is enabled, selects the final revision from a list of revisions
sub select_final {
    my ($doc,@revs) = @_;

    my $final_revn = final_revision($doc);
    if (defined $final_revn) {
        for my $rev (@revs) {
            if ($rev->{revn} == $final_revn) {
                return $rev;
            }
        }
    }
    return 0;
}


# Selects the given revisions from a list of revisions
sub select_revs {
    my ($revn,@revs) = @_;

    my @ret;
    for my $rev (@revs) {
	if ($revn == $rev->{revn}) {
	    push @ret, $rev;
	}
    }
    return \@ret;
}

# Various pathnames
sub revpath {
    my ($doc,$revn,$style) = @_;
    return "$ZPUB_INSTANCES/$CUST/output/$doc/archive/$revn/$style";
}
sub repopath {
    return "$ZPUB_INSTANCES/$CUST/repos/source";
}


my %format_order = (
	'pdf' => 1,
	'epub' => 2,
	'html-dir' => 3,
	'html-zip' => 4,
	'chm' => 5,
);

# Information about the files in a given revision of
# a document
sub collect_output {
    my ($doc,$revn,$style) = @_;

    my $path = revpath($doc,$revn,$style);

    my @ret;
    for my $file (bsd_glob("$path/*")) {
	my $filename = basename($file);
	my $type;
	if      ($filename =~ /\.chm$/) {
	    $type = 'chm';
	} elsif ($filename =~ /\.epub$/) {
	    $type = 'epub';
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
        else          {$size = format_bytes(-s $file);}

	my $date = $strp_ctime->parse_datetime(ctime(stat($file)->mtime));
	$date->set_formatter($strp_absolute);
	$date->set_locale('de_DE');

	my $url = sprintf "%s/%s/archive/%d/%s/%s", $SETTINGS{rootpath}, $doc,$revn,$style,$filename;
	
	push @ret, {
	    filename => $filename,	
	    type => $type,	
	    size => $size,
	    date => $date,
	    url => $url,
	};
    }
    @ret = sort { ($format_order{$a->{type}} || $a) cmp ($format_order{$b->{type}} || $b) } @ret;
    return \@ret;
}

# Given a revision number, returns the date, author and message
# in a hash
sub rev_info {
    my ($revn) = @_;

    my $look = SVN::SVNLook->new(repo => repopath(), cmd => '/usr/bin/svnlook');
    my ($author, $raw_date, $log_msg) = $look->info(revision => $revn);
    $raw_date =~ m/^(.*) \(.*\)$/;
    my $date = $strp_svn->parse_datetime($1) || die "Could not parse date \"$raw_date\" of rev $revn in repo \"". repopath() . "\"\n";
    $date->set_formatter($strp_absolute);
    $date->set_locale('de_DE');

    return {date => $date,
            author => $author,
            log_msg => $log_msg}
}

# Gathers information about jobs in the spooler
sub collect_jobs {
    my %ret;
    
    for my $dir (qw/fail todo wip/) {
	my @list;
	opendir(DIR, "$ZPUB_SPOOL/$dir") || die "can't opendir $ZPUB_SPOOL/$dir: $!";
	for my $jobname (grep { (not /^\./) && -f "$ZPUB_SPOOL/$dir/$_" } readdir(DIR)) {
	    my (@lines) = read_file("$ZPUB_SPOOL/$dir/$jobname");
	    unless (@lines) {die "can't open $ZPUB_SPOOL/$dir/$jobname: $!"};
	    chomp (@lines);
	    my ($cust,$revn,$doc,$style,$outdir) = @lines;
	    next unless $cust eq $CUST;
	    my $info = lazy(\&rev_info,$revn);

	    push @list, {
		jobname => $jobname,
		revn    => $revn,
		doc     => $doc,
		style   => $style,
		outdir  => $outdir,
		info    => $info,
	    };
	}
    	@list = sort {$b->{revn} <=> $a->{revn}} @list;
	$ret{$dir} = \@list;;
	closedir DIR;
    }
    return \%ret;
}

# Returns jobs that are newer than the given document/revision
sub newer_jobs {
    my ($doc,$rev) = @_;

    my $ret = collect_jobs();
    for my $jobs (values %$ret) {
	$jobs = [ grep { $_->{doc} eq $doc && $_->{revn} >= ($rev ? $rev->{revn} : -1) } @$jobs ]
    }
    return $ret;
}

# Slurps the htpasswd file for the current customer
sub read_htpasswd {
    if ( -r "$ZPUB_INSTANCES/$CUST/settings/htpasswd") {
	return scalar(read_file("$ZPUB_INSTANCES/$CUST/settings/htpasswd")
		or die "Could not read htpasswd: $!")
    } else {
	return ""
    }
}

# Writes the htpasswd file for the current customer
sub write_htpasswd {
	write_file("$ZPUB_INSTANCES/$CUST/settings/htpasswd", \$_[0])
			or die "Could not write htpasswd: $!";
}

# Is the current user an admin?
sub is_admin {
    $USER or die "zpub accessed without an user name\n";
    return exists $SETTINGS{admins}{$USER};
}
    
# Read Settings
sub read_settings {
    # Customer Name
    $SETTINGS{cust_name} = read_file("$ZPUB_INSTANCES/$CUST/conf/cust_name")
	or die "Could not read cust_name: $!";
    chomp($SETTINGS{cust_name});
    
    # Admins
    if ( -f "$ZPUB_INSTANCES/$CUST/settings/htpasswd") {
	my @admins = read_file("$ZPUB_INSTANCES/$CUST/conf/admins");
	unless (@admins) { die "Could not read admins: $!" };
	chomp(@admins);
	$SETTINGS{admins} = to_hash(@admins);
    } else {
	$SETTINGS{admins} = {};
    }

    # URL and root path
    if ( -f "$ZPUB_INSTANCES/$CUST/conf/hostname") {
	$SETTINGS{hostname} = read_file("$ZPUB_INSTANCES/$CUST/conf/hostname");
	chomp($SETTINGS{hostname});
    } else {
	$SETTINGS{hostname} = "$CUST.zpub.de";
    }

    if ( -f "$ZPUB_INSTANCES/$CUST/conf/rootpath") {
	$SETTINGS{rootpath} = read_file("$ZPUB_INSTANCES/$CUST/conf/rootpath");
	chomp($SETTINGS{rootpath});
	if ($SETTINGS{rootpath}) {
	    unless ($SETTINGS{rootpath} =~ m'^/') {
		die "Setting rootpath (\"$SETTINGS{rootpath}\") does not begin with a slash.\n"
	    }
	    if ($SETTINGS{rootpath} =~ m'/$') {
		die "Setting rootpath (\"$SETTINGS{rootpath}\") must not end with a slash.\n"
	    }
	}
    } else {
	$SETTINGS{rootpath} = "";
    }

    
    # Enabled features
    if ( -f "$ZPUB_INSTANCES/$CUST/conf/features") {
	my @features = read_file("$ZPUB_INSTANCES/$CUST/conf/features");
	unless (@features) { die "Could not read features: $!" };
	chomp(@features);
	$SETTINGS{features} = to_hash(@features);
    } else {
	$SETTINGS{features} = {};
    }

    # Default style
    my @styles = read_file("$ZPUB_INSTANCES/$CUST/conf/default_style")
	or die "Could not read default_style: $!";
    chomp(@styles);
    $SETTINGS{default_style} = \@styles;

    # Final style
    if ($SETTINGS{features}{final_approve}) {
    	my @styles = read_file("$ZPUB_INSTANCES/$CUST/conf/final_style")
	    or die "Could not read final_style: $!";
	chomp(@styles);
	$SETTINGS{final_style} = \@styles;
    }
}

# If final_approve is enabled, this returns the approved
# revision for the given document, or "undef" if there is none.
sub final_revision {
    my ($doc) = @_;

    return read_doc_setting($doc,"final_rev"); 
}

# Returns the subscribers of the document
sub read_subscribers {
    my ($doc) = @_;

    return read_doc_setting($doc,"subscribers") || ''; 
}

# Reads a per-document settings file, returning undef if it does not exit
sub read_doc_setting {
    my ($doc,$what) = @_;

    if ( -f "$ZPUB_INSTANCES/$CUST/settings/$what/$doc") {
	my $ret = read_file("$ZPUB_INSTANCES/$CUST/settings/$what/$doc")
	    or die "Coult not read $ZPUB_INSTANCES/$CUST/settings/$what/$doc: $!\n";
	chomp ($ret);
	return $ret;
    } else {
	return undef
    }
}

# Write a per-document settings file
sub write_doc_setting {
    my ($doc,$what,$value) = @_;

    write_file("$ZPUB_INSTANCES/$CUST/settings/$what/$doc", $value)
	    or die "Coult not write $ZPUB_INSTANCES/$CUST/settings/$what/$doc: $!\n";
}

# Get various system statistics
sub collect_sysstatus {
    my $ret = {};

    my $ref = df("$ZPUB_INSTANCES/$CUST/output",1);
    $ret->{df} = format_bytes($ref->{bavail});

    $ret->{load} = join ", ",Sys::CpuLoad::load();

    return $ret;
}

1;
