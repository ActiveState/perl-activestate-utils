package ActiveState::Unix::Pw;

use strict;
use ActiveState::Handy qw(run);

use base 'Exporter';
our @EXPORT_OK;

my %cmd;
my %commands = (
        useradd => 'useradd',
        userdel => 'userdel',
        groupadd => 'groupadd',
        groupdel => 'groupdel',
        su       => 'su',
);

if ($^O eq 'aix') {
    @commands{qw(useradd userdel groupadd groupdel)} =
              qw(mkuser  rmuser  mkgroup  rmgroup);
}

for my $c (keys %commands) {
    $cmd{$c}{cmd} = [$commands{$c}];
    push(@EXPORT_OK, $c);
}

if (-x "/usr/sbin/pw") {
    for my $v (values %cmd) {
	unshift(@{$v->{cmd}}, "/usr/sbin/pw");
    }
}
else {
    for my $v (values %cmd) {
        if ($v->{cmd}[0] eq 'mkuser' or $v->{cmd}[0] eq 'mkgroup') {
            substr($v->{cmd}[0], 0, 0) = "/usr/bin/";
        }
        else {
            substr($v->{cmd}[0], 0, 0) = "/usr/sbin/";
        }
    }
}

# XXX this whole thing ought to be generalized and totally table driven

sub useradd {
    my %opt = @_;
    my @cmd = @{$cmd{useradd}{cmd}};
    

    if (exists $opt{comment}) {
	my $c = delete $opt{comment};
        if ($^O eq 'aix') {
            push(@cmd, "gecos=$c");
        }
        else {
            push(@cmd, "-c", $c); 
        }
    }

    if (my $h = delete $opt{home}) {
        if ($^O eq 'aix') {
            push(@cmd, "home=$h");
        }
        else {
            push(@cmd, "-d", $h);
        }
    }

    if (delete $opt{create_home}) {
        if ($^O eq 'aix') {
            # ignore for aix - always create
        }
        else {
            push(@cmd, "-m");
        }
    }

    if (my $g = delete $opt{group}) {
	$g = [$g] unless ref($g) eq 'ARRAY';
        if ($^O eq 'aix') {
            push(@cmd, "groups=" . join(',', grep defined, @$g));
        }
        else {
            my $pg = shift @$g;
            push(@cmd, "-g", $pg) if defined $pg;
            push(@cmd, "-G", join(',', @$g)) if scalar @$g > 0;
        }
    }

    # must be last
    if (my $u = delete $opt{user}) {
	push(@cmd, "-n") if $^O eq "freebsd";
	push(@cmd, $u);
    }
    else {
	die "user option is mandatory for useradd";
    }

    _run('useradd', \%opt, \@cmd);
}

sub userdel {
    my %opt = @_;
    my @cmd = @{$cmd{userdel}{cmd}};
    my $user;
    my $home;
    my $norun = $opt{_norun};
    
    if ($^O eq 'aix') {
        if (delete $opt{remove_home} and $opt{user}) {
            # find user's home dir for AIX
            my $lsuser = `/usr/sbin/lsuser -a home $opt{user} 2>/dev/null`;
            if (!$? and $lsuser) {
		chomp($lsuser);
                ($home = $lsuser) =~ s/^.*?=//;
            }
        }
    }
    else {
        push(@cmd, "-r") if delete $opt{remove_home};
    }
    
    if ($user = delete $opt{user}) {
	push(@cmd, "-n") if $^O eq "freebsd";
	push(@cmd, $user);
    }
    else {
	die "user option is mandatory for userdel";
    }
    my ($rc,@rc);
    if (wantarray and $norun) {
        @rc = _run('userdel', \%opt, \@cmd);
    }
    else {
        $rc = _run('userdel', \%opt, \@cmd);
    }
        
    # manually remove home dir for AIX
    if ($home) {
        my @rm_cmd = ('rm','-rf',$home);
        # don't run it, just show the command we would have run
        if ($norun) {
            wantarray ? return (@cmd,';',@rm_cmd) : return $rc.";"._shell_escape(@rm_cmd);
        }
        # run the command
        elsif ($rc) {
            $rc = run(@rm_cmd);
        }
    }

    $rc;
}

sub groupadd {
    unshift(@_, "group") if @_ == 1;
    my %opt = @_;
    my @cmd = @{$cmd{groupadd}{cmd}};

    if (exists $opt{gid}) {
	my $gid = int(delete $opt{gid});
	if ($^O eq 'aix') {
            push(@cmd, "id=$gid");
	}
	else {
            push(@cmd, "-g", $gid);
	}
    }

    if ($^O eq 'aix') {
        delete $opt{unique}; # ignore for aix - can't override
    }
    else {
        push(@cmd, "-o") if exists $opt{unique} && !delete $opt{unique};
    }
    
    #Redhat Linux specific - on other OS's _run() will warn about unknown options
    if ($^O eq 'linux') {
        push(@cmd, "-r") if delete $opt{system};
        push(@cmd, "-f") if delete $opt{force};
    }

    # must be last
    if (my $g = delete $opt{group}) {
	push(@cmd, $g);
    }
    else {
	die "user option is mandatory for groupadd";
    }

    _run('groupadd', \%opt, \@cmd);
}

sub groupdel {
    unshift(@_, "group") if @_ == 1;
    my %opt = @_;
    my @cmd = @{$cmd{groupdel}{cmd}};

    if (my $g = delete $opt{group}) {
	push(@cmd, $g);
    }
    else {
	die "group option is mandatory for groupdel";
    }
    _run('groupdel', \%opt, \@cmd);
}

sub _run {
    my($f, $opt, $cmd) = @_;

    my $norun = delete $opt->{_norun};
    my $nocroak = delete $opt->{_nocroak};

    for my $o (sort keys %$opt) {
	warn "Unrecognized option '$o' in $f";
    }

    #use Data::Dump; Data::Dump::dump($cmd);
    substr($cmd->[0], 0, 0) = "-" if $nocroak;

    return run(@$cmd) unless $norun;
    wantarray ? @$cmd : _shell_escape(@$cmd);
}

sub _shell_escape {
    my @words = @_;
    for (@words) {
	# XXX real escapes etc
	$_ = qq("$_") if /\s/;
    }
    join(" ", @words);
}


sub su {
    my %opt = @_;
    my @cmd = ();

    # su Notes
    # Linux     /bin            su - user -c "command args"
    # Solaris   /usr/bin        su - user -c "command args"
    # FreeBSD   /usr/bin        su - user -c "command args"
    # HP-UX     /usr/bin        su - user -c "command args"
    # AIX       /usr/bin        su - user "-c dir/command options"
    if ($^O eq 'linux') {
        push(@cmd, '/bin/su');
    }
    else {
        push(@cmd, '/usr/bin/su');
    }

    my $login = "-" if delete $opt{login};

    if (my $u = delete $opt{user}) {
        push(@cmd, $login) if $login;
        push(@cmd, $u);
    }
    else {
        die "user option is mandatory for su" unless $u;
    }

    if (my $cmd = delete $opt{command}) {
        if ($^O eq 'aix') {
            push(@cmd, "-c $cmd");
        }
        else {
            push(@cmd, "-c", $cmd);
        }
    }

    _run('su', \%opt, \@cmd);
}
    
1;

__END__

=head1 NAME

ActiveState::Unix::Pw - Portable manipulation of user accounts

=head1 SYNOPSIS

 use ActiveState::Unix::Pw qw(useradd userdel groupadd groupdel su);

=head1 DESCRIPTION

The C<ActiveState::Unix::Pw> module provide functions to add and
remove user accounts from the system.  It is a portable interface to
the system utility commands that manipulate the passwd and group
databases.

All functions provided take key/value pairs as arguments.  The
following special arguments are recognized by all functions:

=over

=item _norun

Instead of feeding commands to the run() function (see
L<ActiveState::Handy>) the commands to run are returned as a string.

=item _nocroak

Tell the run() not to ignore errors.  By default it will croak if the
command signals an error.

=back

The following functions are provided by this module.  None of them are
exported by default:

=over

=item useradd( %opts )

The following options are recognized:

=over

=item user

The username to use.  Mandatory.

=item comment

The password comment field.  Usually the full name of the user.

=item home

The home directory to use.

=item create_home

Boolean; if TRUE create the home directory and set it up.  If FALSE
only the password database is updated.

=item group

What group or group should this user be part of.  The value can either
be a plain scalar or an array reference if multiple groups are to be
specified.  When multiple groups are specified, then the first group
will be the primary group.  The first group can be specified as
C<undef> to let the system select a default primary group.

=back

=item userdel( %opts )

The following options are recognized:

=over

=item user

The username to delete.  Mandatory.

=item remove_home

Boolean; if TRUE then the home directory will be deleted as well as
the user information.

=back

=item groupadd( %opts )

The following options are recognized:

=over

=item group

The group name to add.  Mandatory.

=item gid

A group identifier.  If left unspecified a free one will be
assigned.

=item unique

Boolean; if TRUE non-unique gids are allowed.  Does not work everywhere.

=item system

Make a system account.  Only available on Linux.

=item force

Boolean; this will cause failure if the group already exists.  Only
available on Linux.

=back

=item groupdel( %opts )

The following extra option is recognized:

=over

=item group

The value is the name of the group to delete.  Mandatory.

=back

=item su( %opts )

The following options are recognized:

=over

=item user

The username to su to.  Mandatory.

=item command

The command to execute as the specified user.

=item login

If true, makes the shell a login shell.

=back

=back

=cut

=head1 COPYRIGHT

Copyright (C) 2003 ActiveState Corp.  All rights reserved.

=head1 SEE ALSO

L<ActiveState::Handy>
