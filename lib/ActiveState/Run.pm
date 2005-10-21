package ActiveState::Run;

use strict;

our $VERSION = '1.00';

use base 'Exporter';
our @EXPORT_OK = qw(run shell_quote decode_status);

require Carp;

sub run {
    my @cmds = @_;

    my $ignore_err = $cmds[0] =~ s/^-//;
    my $silent = $ENV{AS_RUN_SILENT};
    if ($cmds[0] =~ s/^@(-)?//) {
	$silent++;
	$ignore_err++ if $1;
    }
    unless ($silent) {
	my $prefix = $ENV{AS_RUN_PREFIX};
	$prefix = "" unless defined $prefix;
	if (@cmds == 1) {
	    print "$prefix$cmds[0]\n";
	}
	else {
	    print $prefix . shell_quote(@cmds) . "\n";
	}
    }

    system(@cmds) == 0 || $ignore_err || do {
	my $msg = "Command";
	if ($? == -1) {
	    my $cmd = $cmds[0];
	    $cmd =~ s/\s.*// if @cmds == 1;
	    $msg .= qq( "$cmd" failed: $!);
	}
	else {
            $msg .= " " . decode_status();
	}
	$msg .= ":\n  @cmds\n  stopped";

        Carp::croak($msg);
    };
    return $?;
}

sub shell_quote {
    my @copy;
    for (defined(wantarray) ? (@copy = @_) : @_) {
	if ($^O eq "MSWin32") {
	    s/(\\*)\"/$1$1\\\"/g;
	    $_ = qq("$_") if /\s/ || $_ eq "";
	}
	else {
	    if ($_ eq "" || /[^\w\.\-\/]/) {
		s/([\\\$\"\`])/\\$1/g;
		$_ = qq("$_");
	    }
	}
    }
    wantarray ? @copy : join(" ", @copy);
}

sub decode_status {
    my $rc = shift || $?;

    my $exit_status = ($rc & 0xff00) >> 8;
    my $signal = $rc & 0x7f;
    my $dumped_core = $rc & 0x80;
    my $ifstopped = ($rc & 0xff) == 0x7f;
    my $ifexited = $signal == 0;
    my $ifsignaled = !$ifstopped && !$ifexited;

    return (WIFEXITED   => $ifexited,
            $ifexited ? (WEXITSTATUS => $exit_status) : (),
            WIFSIGNALED => $ifsignaled,
            $ifsignaled ? (WTERMSIG    => $signal) : (),
            WIFSTOPPED  => $ifstopped,
            $ifstopped ? (WSTOPSIG    => $exit_status) : (),
            WCOREDUMP   => $dumped_core) if wantarray;

    my $msg = "";
    $msg .= " exits with $exit_status" if $ifexited and $exit_status;
    $msg .= " killed by signal $signal" if $ifsignaled;
    $msg .= " stopped by signal $exit_status" if $ifstopped;
    $msg .= " (core dumped)" if $dumped_core;
    $msg =~ s/^\s//;
    return $msg;
}

1;

=head1 NAME

ActiveState::Run - Collection of small utility functions

=head1 SYNOPSIS

 use ActiveState::Handy qw(run);
 run("ls -l");

=head1 DESCRIPTION

This module provides a collection of small utility functions for
running external programs.

The following functions are provided:

=over 4

=item decode_status( )

=item decode_status( $rc )

Will decode the given return code (defaults to $?) and return the 
exit value, the signal it was killed with, and if it dumped core.

In scalar context, it will return a string explaining what happened, or 
an empty string if no error occured.

  my $foo = `ls`;
  my $err = decode_status;
  die "ls failed: $err" if $err;

In array context, it will return a list of key/value pairs containing:

=over 4

=item WIFEXITED

True when the status code indicates normal termination.

=item WEXITSTATUS

If WIFEXITED, this will contain the low-order 8 bits of the status
value the child passed to exit or returned from main.

=item WIFSIGNALED

Non-zero if process was terminated by a signal.

=item WTERMSIG

If WIFSIGNALED, the terminating signal.

=item WIFSTOPPED

Non-zero if the process was stopped.

=item WSTOPSIG

If WIFSTOPPED, the signal that stopped the process.

=item WCOREDUMP

Nonzero if the process dumped core.

=back

Example:

  my $foo = `ls`;
  my %err = decode_status;
  die "ls dumped core" if $err{WCOREDUMP};

=item run( $cmd, @args )

Works like the builtin system() but will by default print commands to
stdout before it execute them and raise an exception (die) if the
command fails (returns non-zero status).  Like for the command
specifications for make(1), you can prefix the command with "@" to
suppress the echo and with "-" to suppress the status check.

The environment variables AS_RUN_SILENT and AS_RUN_PREFIX influence
printing as well, see L<"ENVIRONMENT">.

=item shell_quote( @args )

Will quote the arguments provided so that they can be passed to the
command shell without interpretation by the shell.  This is useful
with run() when you can't provide separate @args, e.g.:

   run(shell_quote("rm", "-f", @files) . " >dev/null");

In list context it returns the same number of values as arguments
passed in.  Only those arg values that need quoting will be quoted.

In scalar context it will return a single string with all the quoted
@args separated by space.

In void context it will attempt inline modification of the @args
passed.

=back

=head1 ENVIRONMENT

If the AS_RUN_SILENT environment variable is TRUE, then printing of
the command about to run for run() is suppressed.

If the AS_RUN_PREFIX environment variable is set, then the printed
command is prefixed with the given string.  If AS_RUN_SILENT is TRUE,
then this value is ignored.

=head1 BUGS

none.

=cut
