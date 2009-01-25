use File::Basename qw/dirname basename/;
use File::Slurp;
use File::stat;
use Time::localtime;
use SVN::SVNLook;
use DateTime;


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
    opendir(DIR, "$ZPUB/$CUST/output/") || die "can't opendir $ZPUB/$CUST/output/: $!";
    my @files = grep { (not /^\./) && -d "$ZPUB/$CUST/output/$_" } readdir(DIR);
    closedir DIR;
    return @files;
}

# Returns a list of all documents of the customer
# Each element has three 
sub collect_revisions {
    my ($doc) = @_;
    
    my %hash;
    opendir(DIR, "$ZPUB/$CUST/output/$doc/archive")
	|| die "can't opendir $ZPUB/$CUST/output/$doc/archive: $!";
    for (readdir(DIR)) {
	if (-d "$ZPUB/$CUST/output/$doc/archive/$_" && /(\d+)-(.*)/) {
	    $hash{$1} ||= {
		    revn => $1,
		    info  => lazy(\&rev_info,$1),
		    styles => [],
	    };

	    push @{$hash{$1}{styles}}, {
		style => $2,
		files => lazy(\&collect_output, $doc, $1, $2),
	    }
	}
    } 
    closedir DIR;
    return sort {$b->{revn} <=> $a->{revn}} (values %hash);
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

# If final_approve is enabled, selects the final revision from a list of revisions
sub select_final {
    my ($doc,@revs) = @_;

    my $final_revn = final_revision($doc);

    for my $rev (@revs) {
	if ($rev->{revn} == $final_revn) {
	    return $rev;
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
    return "$ZPUB/$CUST/output/$doc/archive/$revn-$style";
}
sub repopath {
    return "$ZPUB/$CUST/repos/source";
}

# Information about the files in a given revision of
# a document
sub collect_output {
    my ($doc,$revn,$style) = @_;

    my $path = revpath($doc,$revn,$style);

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

	my $url = sprintf "/%s/archive/%d-%s/%s", $doc,$revn,$style,$filename;
	
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
    my ($revn) = @_;

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
	for my $jobname (grep { (not /^\./) && -f "$ZPUB/spool/$dir/$_" } readdir(DIR)) {
	    my (@lines) = read_file("$ZPUB/spool/$dir/$jobname");
	    unless (@lines) {die "can't open $ZPUB/spool/$dir/$jobname: $!"};
	    chomp (@lines);
	    my ($cust,$revn,$doc,$style,$outdir) = @lines;
	    next unless $cust eq $CUST;
	    my $info = lazy(\&rev_info,$revn);

	    push @{$ret{$dir}}, {
		jobname => $jobname,
		revn    => $revn,
		doc     => $doc,
		style   => $style,
		outdir  => $outdir,
		info    => $info,
	    };
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
	$jobs = [ grep { $_->{doc} eq $doc && $_->{revn} >= $rev->{revn} } @$jobs ]
    }
    return $ret;
}

# Slurps the htpasswd file for the current customer
sub read_htpasswd {
    if ( -r "$ZPUB/$CUST/settings/htpasswd") {
	return scalar(read_file("$ZPUB/$CUST/settings/htpasswd")
		or die "Could not read htpasswd: $!")
    } else {
	return ""
    }
}

# Writes the htpasswd file for the current customer
sub write_htpasswd {
	write_file("$ZPUB/$CUST/settings/htpasswd", \$_[0])
			or die "Could not write htpasswd: $!";
}

# Is the current user an admin?
sub is_admin {
    $USER or die "zpub accessed without an user name\n";
    return $SETTINGS{admins}{$USER};
}
    
# Read Settings
sub read_settings {
    # Admins
    if ( -f "$ZPUB/$CUST/settings/htpasswd") {
	my @admins = read_file("$ZPUB/$CUST/conf/admins");
	unless (@admins) { die "Could not read admins: $!" };
	chomp(@admins);
	$SETTINGS{admins} = to_hash(@admins);
    } else {
	$SETTINGS{admins} = {};
    }
    
    # Enabled features
    if ( -f "$ZPUB/$CUST/conf/features") {
	my @features = read_file("$ZPUB/$CUST/conf/features");
	unless (@features) { die "Could not read features: $!" };
	chomp(@features);
	$SETTINGS{features} = to_hash(@features);
    } else {
	$SETTINGS{features} = {};
    }

    # Default style
    $SETTINGS{default_style} = read_file("$ZPUB/$CUST/conf/default_style")
	or "Could not read default_style: $!";
    chomp($SETTINGS{default_style});

    # Final style
    if ($SETTINGS{features}{final_approve}) {
	$SETTINGS{final_style} = read_file("$ZPUB/$CUST/conf/final_style")
	    or "Could not read final_style: $!";
	chomp($SETTINGS{final_style});
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

    if ( -f "$ZPUB/$CUST/settings/$what/$doc") {
	my $ret = read_file("$ZPUB/$CUST/settings/$what/$doc")
	    or die "Coult not read $ZPUB/$CUST/settings/$what/$doc: $!\n";
	chomp ($ret);
	return $ret;
    } else {
	return undef
    }
}

# Write a per-document settings file
sub write_doc_setting {
    my ($doc,$what,$value) = @_;

    write_file("$ZPUB/$CUST/settings/$what/$doc", $value)
	    or die "Coult not write $ZPUB/$CUST/settings/$what/$doc: $!\n";
}

1;