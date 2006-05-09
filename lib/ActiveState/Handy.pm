package ActiveState::Handy;

use strict;

our $VERSION = '1.01';

use base 'Exporter';
our @EXPORT_OK = qw(
    add ceil
    cat cat_text
    iso_date iso_datetime
    xml_esc xml_clean
    cp_tree cp_files
);

# legacy
use ActiveState::Run qw(run shell_quote decode_status);
push(@EXPORT_OK, qw(run shell_quote decode_status));

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

sub iso_datetime {
    my($Y, $M, $D, $h, $m, $s) = @_;
    if (@_ == 1) {
	($Y, $M, $D, $h, $m, $s) = (localtime $Y)[5, 4, 3, 2, 1, 0];
	$Y += 1900;
	$M++;
    }
    return sprintf "%04d-%02d-%02dT%02d:%02d:%02d", $Y, $M, $D, $h, $m, $s;
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

 use ActiveState::Handy qw(add);
 my $sum = add(1, 2, 3);

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

=item iso_datetime( $time )

=item iso_datetime( $y, $m, $d, $h, $m, $s )

Returns a ISO 8601 formatted timestamp; YYYY-MM-DDThh:mm:ss format.  See
C<http://www.cl.cam.ac.uk/~mgk25/iso-time.html>.

=item xml_esc( $text )

Will escape a piece of text so it can be embedded as text in an XML
element.

=item xml_clean( $text )

Will remove control characters so it can be embedded as text in an XML
element. Does not perform escaping.

=back

For legacy reasons this module re-exports the functions run(),
shell_quote() and decode_status() from C<ActiveState::Run>.

=head1 BUGS

none.

=head1 SEE ALSO

L<ActiveState::Run>

=cut
