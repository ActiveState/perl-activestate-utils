package ActiveState::Install;

use strict;
our $VERSION = '1.00';

use File::Compare qw(compare);
use Digest::MD5 ();
use HTTP::Date qw(time2iso);
use ActiveState::Prompt qw(enter);

use base 'Exporter';
our @EXPORT = qw(install);
our @EXPORT_OK = qw(installed uninstall summary);

my $owner;
my $group;
my $verbose;
my $pkg;
my $ver;
my $config_file;  # a hash reference
my @rollback_actions;
my @commit_actions;
my %md5_old;
my %md5_new;
my %inode_new;
my %config_old;
my %from;
my %summary;
my $ppmsave;
my $preserve_mtime;

sub install {
    my %args = @_;
    $pkg = delete $args{pkg}        || die "pkg argument missing";
    $ver = delete $args{ver}        || die "ver argument missing";
    my $files = delete $args{files} || die "files argument missing";
    my $etc = delete $args{etc}     || die "etc argument missing";

    my $lockfile = delete $args{lock_file};
    unless (defined $lockfile) {
	$lockfile = __PACKAGE__ . ".lck";
	$lockfile =~ s/::/_/g;
    }

    $owner = delete $args{owner};
    $group = delete $args{group};
    $preserve_mtime = delete $args{preserve_mtime};

    $verbose = delete $args{verbose};
    unless (defined $verbose) {
	$verbose = exists $ENV{AS_INSTALL_VERBOSE} ?
	    $ENV{AS_INSTALL_VERBOSE} : 1;
    }

    $config_file = delete $args{config_files} || {};
    for my $c (keys %$config_file) {
	die "Configuration file $c is not in package"
	    unless -f $c;
    }

    if (defined($owner) && $owner !~ /^\d+$/) {
	my $uid = getpwnam($owner);
	unless (defined $uid) {
	    # if there is a file with this name use its owner
	    my $gid;
	    ($uid, $gid) = (stat $owner)[4,5] or die "No such user '$owner'";
	    $group = $gid unless defined $group;
	}
	$owner = $uid;
    }

    if (defined $group) {
	if ($group !~ /^\d+$/) {
	    my $gid = getgrnam($group);
	    die "No such group '$group'" unless defined $gid;
	    $group = $gid;
	}
    }
    else {
	$group = -1;  # means unchanged for chown
    }

    if ($^W && %args) {
	warn "Unrecognized install args: " . join(", ", keys %args);
    }

    # reset state
    @rollback_actions = ();
    @commit_actions = ();
    %md5_old = ();
    %md5_new = ();
    %inode_new = ();
    %config_old = ();
    %from = ();
    %summary = ();
    $ppmsave = 0;
    
    # Start installing
    eval {
	# first we lock
	if ($lockfile) {
	    my $tmp = "$etc/lock.$$";
	    die if -e $tmp;
	    open(my $lock, ">", $tmp) || die "Can't create $tmp: $!";
	    print $lock "$pkg-$ver $$\n";
	    close($lock);

	    $lock = "$etc/$lockfile";
	    if (link($tmp, $lock)) {
		_on_commit("unlink", $lock);
		_on_rollback("unlink", $lock);
		unlink($tmp) || die "Can't unlink $tmp";
	    }
	    else {
		unlink($tmp);
		die "Can't obtain installer lock '$lockfile'";
	    }
	};

	# if we have a previous install, then populate %md5_old, %config_old
	my $pkg_file = "$etc/.packages/$pkg";
	if (open(my $f, "<", $pkg_file)) {
	    local $_;
	    my $header = 1;
	    while (<$f>) {
		if ($header) {
		    $header = 0 if /^$/;
		    next;
		}
		chomp;
		my($md5, $config, $file) = split(' ', $_, 3);
		die unless length($md5) == 32;
		$md5_old{$file} = $md5;
		$config_old{$file} = $config;
	    }
	    #use Data::Dump; Data::Dump::dump(\%md5_old);
	}

        # copy files
	for my $from (sort keys %$files) {
	    my $to = $files->{$from};
	    die "There is no '$from' to install from" unless -e $from;
	    
	    if (-d _) {
		# install directory
		die "Can't install a directory on top of $to"
		    if -e $to && !-d _;
		
		for ($from, $to) {
		    $_ .= "/" unless m,/\z,;
		}

		_copy_dir($from, $to);
	    }
	    elsif (-f _) {
		# install file
		_copy_file($from, $to);
	    }
	    else {
		die "Can't install $from since it's neither a regular file nor a directory";
	    }
	}

	# delete old files that are not in the new package
	for my $fname (keys %md5_old) {
	    next if $md5_new{$fname};
	    next unless -e $fname;
	    next if $inode_new{join(":", (stat _)[0,1])};  # safety net

	    if ($config_old{$fname} && _file_md5($fname) ne $md5_old{$fname}) {
		# locally modified configuration file
		_on_commit("rename", $fname, "$fname.ppmdeleted");
	    }
	    else {
		_on_commit("unlink", $fname);
		$summary{del}++;
	    }
	}

	# and finally try to update .package database
	if ($verbose > 1) {
	    print "Update packlist\n";
	}
	unless (-d "$etc/.packages") {
	    mkdir("$etc/.packages", 0755) ||
		die "Can't mkdir $etc/.packages: $!";
	}

	_tmp_save($pkg_file) if -e $pkg_file;
	_create(my $f, $pkg_file);
	print $f "Package: $pkg\n";
	print $f "Version: $ver\n";
	print $f "Date: " . time2iso() . "\n";
	print $f "Installer: " . __PACKAGE__ . " $VERSION\n";
	print $f "\n";
	for my $fname (sort keys %md5_new) {
	    my $c = $config_file->{$from{$fname}} || 0;
	    print $f "$md5_new{$fname} $c $fname\n";
	}
	close($f) || die "Can't write $pkg_file: $!";
	chmod(0444, $pkg_file);
    };
    if ($@) {
	_rollback();
	die;
    }
    else {
	_commit();
    }

    return wantarray ? %summary : ($summary{new} || 0) + ($summary{update} || 0);
}

sub _copy_dir {
    my($from, $to) = @_;

    unless (-d $to) {
	mkdir($to, 0755) || die "Can't mkdir $to: $!";
	print " mkdir $to\n" if $verbose > 1;
	_on_rollback("rmdir", $to);
	$summary{dir}++;
	if (defined $owner) {
	    print " chown($owner, $group, '$to')\n" if $verbose > 2;
	    chown($owner, $group, $to) || die "Can't chown $to: $!";
	}
    }

    local *DIR;
    opendir(DIR, $from) || die "Can't opendir $from: $!";
    my @files = sort readdir(DIR);
    closedir(DIR);

    for my $f (@files) {
	next if $f eq "." || $f eq ".." || $f eq ".exists" || $f =~ /~\z/;
	my $from_file = "$from$f";
	my $to_file = "$to$f";
	if (-l $from_file) {
	    _copy_link($from_file, $to_file);
	}
	elsif (-f _) {
	    _copy_file($from_file, $to_file);
	}
	elsif (-d _) {
	    _copy_dir("$from_file/", "$to_file/");
	}
	else {
	    die "Don't know how to copy $from_file";
	}
    }
}

sub _copy_link {
    my ($from, $to) = @_;
    $from{$to} = $from;

    my $link = readlink($from) || die "can't readlink $from: $!";
    my $tmplink = "$to.$$";
    symlink($link, $tmplink) || die "can't symlink $tmplink: $!";
    _on_commit("rename", $tmplink, $to);
    _on_rollback("unlink", $tmplink);

    $md5_new{$to} = Digest::MD5::md5_hex($link);
    $summary{link}++;
}

sub _copy_file {
    my($from, $to) = @_;
    $from{$to} = $from;

    my $config_flags = $config_file->{$from};

    print "Installing $to\n" if $verbose > 1;
    my $copy_to = $to;

    if ($config_flags) {
	# see http://www.rpmdp.org/rpmbook/node25.html#SECTION02411000000000000000
	my $new_md5 = _file_md5($from);
	my $old_md5 = $md5_old{$to} || "";
	my $cur_md5 = eval { _file_md5($to) } || "";
	print "Config-MD5: new=$new_md5 old=$old_md5 cur=$cur_md5\n"
	    if $verbose > 3;
	
	if ($new_md5 eq $old_md5 && $cur_md5) {
	    # the package has not be modified, current config probably ok
	    $copy_to = undef;
	    print " - not modified (kept as is)\n" if $verbose > 2;
	}
	elsif ($old_md5 eq $cur_md5) {
	    # the file in the package has been modified, but config has
	    # not edited since last install; just overwrite it without
	    # making any backup
	    print " - no local tweaks (updated)\n" if $verbose > 2;
	}
	elsif ($new_md5 eq $cur_md5) {
	    # the file in the package has been modified, but the local
	    # edits made it the same as the new config so there is
	    # no need to copy it over again.
	    $copy_to = undef;
	    print " - local tweaks same as package change (kept as is)\n"
		if $verbose > 2;
	}
	elsif (-e $to) {
	    # the package has been modified and the local file has
	    # been modified. Need to install so that both version
	    # are left around.
	    print " - modified file with local tweaks\n" if $verbose > 2;
	    if ($config_flags == 1) {
		_ppmsave($to);
	    }
	    elsif ($config_flags == 2) {
		$copy_to .= ".ppmdist";
		$from{$copy_to} = $from;
	    }
	    else {
		die "Bad config flag '$config_flags'";
	    }
	}
	elsif ($old_md5) {
	    print " - file has disappeared\n" if $verbose > 2;
	}
    }
    elsif (-e $to) {
	if (-f _ && compare($from, $to) == 0) {
	    $copy_to = undef;
	}
    }

    if (defined $copy_to) {
	my $md5 = Digest::MD5->new;
	open(my $in,  "<", $from) || die "Can't open $from: $!";
	binmode($in);

	if (-e $copy_to) {
	    _tmp_save($copy_to);
	    $summary{update}++;
	}
	else {
	    $summary{new}++;
	}
	_create(my $out, $copy_to);
	binmode($out);

	my $n;
	my $buf;
	while ( ($n = read($in, $buf, 4*1024))) {
	    $md5->add($buf);
	    print $out $buf;
	}

	die "Read failed for file $from: $!"
	    unless defined $n;

	close($in);
	close($out) || die "Write failed for file $to";
	$md5_new{$to} = $md5_new{$copy_to} = $md5->hexdigest;
    }
    else {
	$summary{same}++;
	$md5_new{$to} = _file_md5($from);  # still want to keep track of it
    }
    $summary{file}++;

    # Copy certain file attributes too
    my($from_mode, $from_mtime)= (stat $from)[2, 9];
    utime($from_mtime, $from_mtime, $to) if $preserve_mtime;

    # transfer -x bits and turn off -w for non-config files
    my $x = ($from_mode & 0111);
    if ($x || !$config_flags) {
	my $to_mode = (stat $to)[2];
	my $new_mode = $to_mode | $x;
	$new_mode &= ~0222 unless $config_flags;
	if ($new_mode != $to_mode) {
	    printf " chmod(%04o, '%s')\n", $new_mode, $to if $verbose > 2;
	    chmod($new_mode, $to) || die "Can't chmod: $!";
	}
    }
    
    if (defined $owner) {
	print " chown($owner, $group, '$to')\n" if $verbose > 2;
	chown($owner, $group, $to) || die "Can't chown: $!";
    }

    # we remember the inode of installed files
    $inode_new{join(":", (stat $to)[0,1])}++;
}

sub _ppmsave {
    my $file = shift;
    if ($verbose) {
	(my $base = $file) =~ s,.*/,,;
	print "Renamed '$file' as '$base.ppmsave'\n" if $verbose;
    }
    $ppmsave++;
    rename($file, "$file.ppmsave") || die "Can't rename $file";
    _on_rollback("rename", "$file.ppmsave", $file);
}

sub _file_md5 {
    my $file = shift;
    open(my $f, "<", $file) || die "Can't open $file: $!";
    binmode($f);
    return Digest::MD5->new->addfile($f)->hexdigest;
}

sub _create {
    open($_[0], ">", $_[1]) || die "Can't create '$_[1]': $!";
    _on_rollback("unlink", $_[1]);
}

sub _tmp_save {
    my $file = shift;
    my $tmp = "$file.save-$$";
    die "Can't save to $tmp since it exists" if -e $tmp;
    print " save as $tmp\n" if $verbose > 3;
    rename($file, $tmp) || die "Can't rename as $tmp: $!";
    _on_rollback("rename", $tmp, $file);
    _on_commit("unlink", $tmp);
}

sub _on_rollback {
    push(@rollback_actions, [@_]);
}

sub _on_commit {
    push(@commit_actions, [@_]);
}

sub _rollback {
    return unless @rollback_actions;
    print "Undo partial install\n" if $verbose;
    _do([reverse @rollback_actions]);
}

sub _commit {
    if (@commit_actions) {
	print "Commit\n" if $verbose > 1;
	_do(\@commit_actions);
    }

    # summary
    if ($verbose) {
	print "\n$pkg-$ver installed: ", summary(\%summary), "\n\n";
	#use Data::Dump; printf "\$summary = %s\n", Data::Dump::dump(\%summary);

	if ($ppmsave) {
	    print <<EOM;
### Some of the updated $pkg configuration files have been modified
### on this system since the last upgrade.  The edited files have been
### renamed with a .ppmsave extension.  Please consider reintegrating
### your changes.

EOM
            enter();
	    print "\n";
	}
    }
    return;
}

sub _do {
    my $actions = shift;
    
    for my $a (@$actions) {
	print " - @$a\n" if $verbose > 2;
	my($op, @args) = @$a;
	if ($op eq "rmdir") {
	    for my $d (@args) {
		rmdir($d) || warn "Can't rmdir($d): $!";
	    }
	}
	elsif ($op eq "unlink") {
	    unlink(@args) || warn "Can't unlink(@args): $!";
	}
	elsif ($op eq "rename") {
	    rename($args[0], $args[1]) || warn "Can't rename(@args): $!";
	}
	else {
	    warn "Don't know how to '$op'";
	}
    }
}

sub summary {
    my $hash = shift;
    my @s;

    for (["new", "file", "created"],
	 ["dir", "dir", "created"],
	 ["update", "file", "updated"],
	 ["same", "file", "unchanged"],
	 ["del", "file", "deleted"],
	 ["link", "link", "created"],
	)
    {
	my $c = $hash->{$_->[0]} || next;
	my $str = "$c $_->[1]";
	$str .= "s" if $c != 1;
	$str .= " $_->[2]";
	push(@s, $str);
    }

    join(", ", @s);
}

sub installed {
    my %args = @_;
    my $pkg = delete $args{pkg}     || die "pkg argument missing";
    my $etc = delete $args{etc}     || die "etc argument missing";
    my $pkg_file = "$etc/.packages/$pkg";

    if ($^W && %args) {
	warn "Unrecognized install args: " . join(", ", keys %args);
    }

    return ActiveState::Install::Pkg->new($pkg_file);
}

sub uninstall {
    die "NYI";
}

package ActiveState::Install::Pkg;

sub new {
    my($class, $pkg_file) = @_;
    open(my $f, "<", $pkg_file) || return undef;

    my $self = bless { pkg_file => $pkg_file, files=> {} }, $class;

    local $_;
    my $header = 1;
    while (<$f>) {
	if ($header) {
	    if (/^(\S+):\s*(.*)/) {
		my($k, $v) = (lc($1), $2);
		$k =~ s/-/_/g;
		$self->{$k} = $v;
	    }
	    elsif (/^$/) {
		$header = 0;
	    }
	    else {
		die;
	    }
	}
	else {
	    chomp;
	    my($md5, $config, $file) = split(' ', $_, 3);
	    die unless length($md5) == 32;
	    $self->{files}{$file} = [$md5, $config];
	}
    }

    return $self;
}

sub files {
    my $self = shift;
    return keys %{$self->{files}};
}

sub config_files {
    my $self = shift;
    my %c;
    while (my($k,$v) = each %{$self->{files}}) {
	$c{$k} = $v->[1] || next;
    }
    wantarray ? keys %c : \%c;
}

sub has_file {
    my($self, $f) = @_;
    return !!$self->{files}{$f};
}

sub md5_hex {
    my($self, $f) = @_;
    return $self->{files}{$f}[0];
}

sub changed {
    my($self, $f, $new) = @_;
    my $md5 = $self->md5_hex($f) || die "$f not in package";
    $f = $new if defined $new;
    open(my $fh, "<", $f) || die "Can't open $f: $!";
    binmode($fh);
    return Digest::MD5->new->addfile($fh)->hexdigest ne $md5;
}

1;

__END__

=head1 NAME

ActiveState::Install - install packages on the system

=head1 SYNOPSIS

 use ActiveState::Install qw(install);
 install(pkg => "Foo",
         ver => "0.1",
	 etc => "/usr/local/etc",
	 files => { "bin" => "/usr/local/bin" },
	);

=head1 DESCRIPTION

The C<ActiveState::Install> module provide the three functions
install(), installed() and uninstall().  It is a replacement for the
C<ExtUtils::Install> module that comes with perl.  These are some of
the features that set C<ActiveState::Install> apart:

=over

=item *

It does full rollback if it gets into trouble during the installation.

=item *

It knows how to deal with configuration files (like rpm does).  If a
configuration file has been modified, then it is saved away.

=item *

It makes more intelligent noise during the install process.

=item *

It can chown the files it installs.

=item *

It keeps track of installed files and their checksums.

=back

=head2 The install function

The install() function takes a set of key/value pairs as its arguments.
It then installs the indicated files/directories and return a status
value summarizing what it did.  If it get into trouble during install
it croaks.  A normal return always indicates successful install.

The following parameter values might be passed to install().  The
first four parameters; pkg, ver, etc, files are mandatory.

=over

=item pkg

This is the name of the package that is to be installed.  The name
should normally be "-"-separated words.

=item ver

This is the version number of the package to be installed.

=item etc

This is the name of the "etc" directory to use for recording installed
files.

=item files

This is a hash reference that gives the name of the files that should
be copied.  The hash values are the target location.

=item config_files

This is a hash reference that indicates which of the files to be
installed are configuration files.  The hash values give the type of
configuration file; C<1> or C<2>.  Type 1 files are always installed
and if the user has changed them since last install, the user edited
file is left with F<.ppmsave> extension.  Type 2 files are not updated
if the user has edited the file.  Instead the file is installed with
F<.ppmdist> extension.

Locally modified configuration files that are deleted are saved with
the F<.ppmdelete> extension.

=item lock_file

This is the name of the installer lock file to use.  The default is
normally good enough.

=item owner

=item group

These can be used to set up the owner and group that the files should
be installed as.  Normally only C<root> is able to set this.  The
owner can be either a username, a numeric uid or the name of a file.
If it is a file, then owner and gid is taken from the metadata of that
file.

=item preserve_mtime

Boolean attribute that makes the installer duplicate the file
modification time of the source files for the installed files if true.
The default is not to duplicate modification times.

=item verbose

A numeric value that indicates how much noise should be generated
during install.  The default is 1, which outputs a single summary line
of the number of files and directories affected.  A value of 0 make
the installer silent.  Higher value give more verbosity.  If the
verbose parameter is not given then the value is also initialized from
the C<AS_INSTALL_VERBOSE> environment variable.

=back

=head2 The installed function

The installed function also take key/value pairs as for install.  The
only required arguments are C<pkg> and C<etc>.  It returns undef if
the given package is not installed and a package object it it is.  The
package object have the following methods:

=over

=item $pkg->files

Returns the list of files that this package has installed.

=item $pkg->config_files

Returns the list of configuration files that this package has
installed.  In scalar context returns a hash of the same format as the
C<config_files> parameter to install().

=item $pkg->has_file($f)

Check if the given file is installed by this package.

=item $pkg->changed($f)

Returns TRUE if this file has changed.  Will croak if the file was not
in the package.

=item $pkg->changed($f, $new);

Returns TRUE if this $new is the not the same file as the one that was
installed for $f.

=back

=head2 The uninstall function

The uninstall() function will also take a set of key/value pairs as
its argument.  It will then remove the given package from the system.

=head1 BUGS

Should support transactions that span multiple calls to install;
expose commit.  Proposed interface

    install(...., commit => 0);
    install(...., commit => 0);
    commit();

If one of the install() calls fails rollback will take place.  If no
commit() is been called when the script ends, rollback will happen.

Rollback entries should be written to the lock file so that proper
rollback can be performed if the install scripts dies before it could
do it.

More stuff should be influenced by parameters.

The uninstall function is not implemented yet.

=head1 COPYRIGHT

Copyright (c) 2002 ActiveState Corp.  All rights reserved.

=head1 SEE ALSO

L<ExtUtils::Install>

=cut
