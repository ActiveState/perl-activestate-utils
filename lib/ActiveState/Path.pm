package ActiveState::Path;

use strict;

our $VERSION = '0.01';

use base 'Exporter';
our @EXPORT_OK = qw(path_list find_prog realpath);

use constant IS_WIN32 => $^O eq "MSWin32";
use File::Spec::Functions qw(catfile rel2abs);
use File::Basename qw(dirname basename);
use Cwd ();
use Carp ();

sub path_list {
    require Config;
    my @list = split /$Config::Config{path_sep}/, $ENV{PATH}, -1;
    if (IS_WIN32) {
        s/"//g for @list;
        @list = grep length, @list;
        unshift(@list, ".");
    }
    else {
        for (@list) {
            $_ = "." unless length;
        }
    }
    return @list;
}

sub find_prog {
    my $name = shift;
    if ($name =~ m,^\.?/,) {
        return -x $name ? $name : undef;
    }
    # try to locate it in the PATH
    for my $dir (path_list()) {
        my $file = catfile($dir, $name);
        #print STDERR "XXX $file\n";
        return $file if -x $file && -f _;
        if (IS_WIN32) {
            for my $ext (qw(bat exe com cmd)) {
                return "$file.$ext" if -f "$file.$ext";
            }
        }
    }
    return undef;
}

sub realpath {
    my $path = shift;
    if (IS_WIN32) {
        Carp::croak("The path '$path' is not valid\n") unless -e $path;
        return scalar(Win32::GetFullPathName($path));
    }

    lstat($path);  # prime tests on '_'

    Carp::croak("The path '$path' is not valid\n") unless -e _;
    return Cwd::realpath($path) if -d _;

    if (-l _) {
        my %seen;
        $seen{$path}++;
        my $orig_path = $path;
        my $count = 0;
        while (1) {
            my $link = readlink($path);
            die "readlink failed: $!" unless defined $link;
            $path = rel2abs($link, dirname($path));
            Carp::croak("symlink cycle for $orig_path\n") if $seen{$path}++;
            Carp::croak("symlink resolve limit exceeded\n") if ++$count > 10;
            last unless -l $path;
        }
    }

    return catfile(Cwd::realpath(dirname($path)), basename($path));
}

1;

__END__

=head1 NAME

ActiveState::Path - Collection of small utility functions

=head1 SYNOPSIS

  use ActiveState::Path qw(find_prog);
  my $ls = find_prog("ls");

=head1 DESCRIPTION

This module provides a collection of small utility functions dealing
with file paths.

The following functions are provided:

=over 4

=item find_prog( $name )

This function returns the full path to the given program if it can be
located on the system.  Otherwise C<undef> is returned.


=item path_list()

Returns the list of directories that will be searched to find
programs.  The path_list() is deducted from the PATH environment
variable.

=item realpath( $path )

Returns the canonicalized absolute pathname of the path passed in.
All symbolic links are expanded and references to F</./>, F</../> and
extra F</> characters are resolved.  The $path passed in must be an
existing file.  The function will croak if not, or if the symbolic
links can't be expanded.

This differs from the Cwd::realpath() function in that $path does
not have to be a directory.

=back

=head1 BUGS

none.

=cut
