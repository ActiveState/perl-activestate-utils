package ActiveState::Handy;

use strict;

our $VERSION = '0.02';

use base 'Exporter';
our @EXPORT_OK = qw(add cat cat_text iso_date run shell_quote 
                    xml_esc xml_clean ceil cp_tree cp_files);

require Carp;

sub ceil {
    my $n = shift;
    my $i = int $n;
    return $i if $i == $n or $n < 0;
    return ++$i;
}

sub add {
    my $sum = 0;
    $sum += shift while @_;
    return $sum;
}

sub cat {
    my $f = shift;
    open(my $fh, "<", $f) || return undef;
    binmode($fh);
    local $/;
    return scalar <$fh>;
}

sub cat_text {
    my $f = shift;
    open(my $fh, "<", $f) || return undef;
    local $/;
    return scalar <$fh>;
}

sub cp_files {
    require File::Copy;
    require File::Path;

    my($from,$to,@files) = @_;
    File::Path::mkpath($to) unless -d $to;
    foreach my $file (@files) {
	die "$from/$file doesn't exist" unless -f "$from/$file";
	File::Path::mkpath("$to/$1") if $file =~ m|^(.*)/[^/]+$|;
	chmod 0777, "$to/$file";
	File::Copy::copy("$from/$file", "$to/$file")
	    or die "Can't copy '$from/$file' to '$to/$file'";
    }
}

sub cp_tree {
    require File::Copy;
    require File::Path;

    my($from,$to) = @_;
    opendir(my $dir, $from) or die "Can't read directory '$from': $!";
    while (defined(my $file = readdir($dir))) {
	next if $file =~ /^\.\.?$/;
	if (-d "$from/$file") {
	    cp_tree("$from/$file", "$to/$file");
	    next;
	}
	next unless -f "$from/$file";
	File::Path::mkpath($to) unless -d $to;
	chmod 0777, "$to/$file";
	File::Copy::copy("$from/$file", "$to/$file")
	    or die "Can't copy '$from/$file' to '$to/$file'";
    }
}

sub iso_date {
    my($y, $m, $d) = @_;
    if (@_ == 1) {
	($y, $m, $d) = (localtime $y)[5, 4, 3];
	$y += 1900;
	$m++;
    }
    return sprintf "%04d-%02d-%02d", $y, $m, $d;
}

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
	    # decode $?
	    my $exit_value = $? >> 8;
	    my $signal = $? & 127;
	    my $dumped_core = $? & 128;

	    $msg .= " exits with $exit_value" if $exit_value;
	    $msg .= " killed by signal $signal" if $signal;
	    $msg .= " (core dumped)" if $dumped_core;
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

sub xml_esc {
    local $_ = shift;
    tr[\000-\010\013-\037][]d;
    s/&/&amp;/g;
    s/</&lt;/g;
    s/]]>/]]&gt;/g;
    s/([^\n\040-\176])/sprintf("&#x%x;", ord($1))/ge;
    return $_;
}

sub xml_clean {
    local $_ = shift;
    tr[\000-\010\013-\037][]d;
    return $_;
}

1;

=head1 NAME

ActiveState::Handy - Collection of small utility functions

=head1 SYNOPSIS

 use ActiveState::Handy qw(cat run);

 run("ls -l");

=head1 DESCRIPTION

This module provides a collection of small utility functions.

The following functions are provided:

=over 4

=item add( @numbers )

Adds the given arguments together.

=item cat( $file )

Returns the content of a file.  Returns C<undef> if the file could not
be opened.  Unlike the cat(1) command it only takes a single file
name argument.  The file is read in binary mode.

=item cat_text( $file )

Just like cat() but will read the file in text mode.  Makes a
difference on some platforms (like Windows).

=item ceil( $number )

Rounds the number up to the nearest integer.  Same as POSIX::ceil().

=item cp_files( $from, $to, @files )

Copies files from source to destination directory. Destination directory
will be created if it doesn't exist.  Function dies if any file cannot
be found.

=item cp_tree( $from, $to )

Recursively copies all files and subdirectories from source to destination
directory. All destination directories will be created if they don't
already exist.

=item iso_date( $time )

=item iso_date( $y, $m, $d )

Returns a ISO 8601 formatted date; YYYY-MM-DD format.  See
C<http://www.cl.cam.ac.uk/~mgk25/iso-time.html>.

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

=item xml_esc( $text )

Will escape a piece of text so it can be embedded as text in an XML
element.

=item xml_clean ( $text )

Will remove control characters so it can be embedded as text in an XML
element. Does not perform escaping.

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
