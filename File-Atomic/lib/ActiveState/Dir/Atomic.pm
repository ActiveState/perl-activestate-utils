package ActiveState::Dir::Atomic;

use strict;
use ActiveState::File::Atomic;

1;

__END__

=head1 NAME

ActiveState::Dir::Atomic - update directory contents atomically

=head1 SYNOPSIS

  use ActiveState::Dir::Atomic;
  my $at = ActiveState::Dir::Atomic->new($dirname);

  # Typically, an application for AS::Dir::Atomic is to
  # watch for changes to a data directory, and reload a
  # set of data files when a change is detected.
  my $cur = $at->currentpath;
  while (1) {
     
     # do some work with $cur
     
     if ($cur ne $at->currentpath) {
        $cur = $at->currentpath;
        
	# reload data files from $cur
        
     }
  }

=head1 DESCRIPTION

ActiveState::Dir::Atomic makes it easier to write code that modifies a
directory safely. It does this by enforcing a particular directory structure.
It keeps a configurable number of backup directories, and can be used to
rollback a commit.

The directory structure is as follows:

=over 4

=item ROOT/

The "root" of the ActiveState::Dir::Atomic structure.  This is the name of the
directory passed to new().

=item ROOT/.lock

The lock file used if the directory is opened for writing.  Not used for
reading.

=item ROOT/1

=item ROOT/2

=item ROOT/...

The actual directories as exposed to the application.  These directories form
a circular buffer of directories. The active directory cycles through these
numbers over time.  The number of directories is determined by the C<rotate>
parameter to new(); once the directory exists, this parameter is read from the
file F<ROOT/.top>.

=item ROOT/current

A symbolic link that points to the currently active subdirectory. When you
commit(), this symbolic link is updated.

=item ROOT/.top

A file containing the number of backups to keep before commit() overwrites
backups.  When a directory is first created, this number is specified by the
C<rotate> parameter.

=back

This package does I<not> abstract access to the actual directory -- use
standard Perl functions for that. It just ensures that while you modify the
contents of the scratch directory, other applications can safely use the
active directory.

ActiveState::Dir::Atomic provides the following methods:

=over 4

=item new()

   $dir = ActiveState::Dir::Atomic($dirname, %opts);

Creates a new object, opening C<$dirname> for reading or writing.  If the
directory is opened for writing it is locked; otherwise no lock is used.  If
the directory cannot be opened or the lock obtained, the constructor will
croak.

Options are passed as key/value pairs after the directory name.  The supported
options are:

=over 4

=item writable

A boolean.  If true, the directory is opened for writing and is locked
exclusively. You can call the scratchdir(), scratchpath() and commit()
methods.  If not, the directory is opened for reading only, and these methods
will croak if you try to use them.

=item create

A boolean.  If true, and writable is also true, the directory is created if it
does not already exist.  Note that the directory will be created when the
object is created, so it will end up existing and empty even if commit() is
not called.

=item timeout

A number representing seconds.  Normally ActiveState::Dir::Atomic will wait
forever trying to acquire a lock on the directory if C<writable> is true.  You
can specify how long to wait with this option.  The constructor will croak
if it times out waiting for the lock.

=item rotate

A number.  If C<create> is true, and the directory did not exist, this is the
number of backups to keep before commits overwrite old directories.  The
default is 4.  If the directory exists, this number is read from a hidden file
that ActiveState::Dir::Atomic saves when it creates directories.

=back

=item current()

  my $current = $at->current;

Returns the index of the current subdirectory. This method consults the
symbolic link each time it is called, to detect changes by other applications.
The index is always an integer greater than 1.

=item currentpath()

  my $path = $at->currentpath;

Returns the full path to the current subdirectory. This method consults the
symbolic link each time it is called, to detect changes by other applications.

=item scratch()

  my $scratch = $at->scratch;

Returns the index of the directory that will become the current directory if
commit() is called. This croaks if the directory was not opened for writing.

=item scratchpath()

  my $path = $at->scratchpath;

Returns the full path to the directory that will become the current directory
if commit() is called. This croaks if the directory was not opened for writing.

=item version()

  my $version = $at->version;

Returns the "version" of the directory. The version string is an optional
parameter to commit(), and is intended to provide a more useful string than
the directory index number.

=item scan()

  my $num = $at->scan(\&callback);

Invokes the C<&callback> for each subdirectory in the directory, beginning
with the current directory and moving backwards in time.  The callback is
invoked like so:

  &callback($fullpath, $index);

The callback can return false to stop walking.

The C<scan()> method normally returns the number of times the callback was
invoked; however, if the callback is not provided, then C<scan()> returns the
number of subdirectories.

=item commit()

  $at->commit;
  $at->commit($version);

Updates the F<ROOT/current> symbolic link to the next directory. The method
will croak on failure or if the C<writable> option was not passed to the
constructor.

Calling commit() implies close(). You should not call any other method on the
object after calling commit().

=item rollback()

  $at->rollback($index);

Sets the F<ROOT/current> symbolic link to the specified index. Subsequent
calls to commit() will begin overwriting from that index.

=item close()

Reverts any uncommitted changes and unlocks the directory. You should not call
any other methods after calling close().

Normally there is no need to call close() explicitly since the object
destructor will invoke it when the object goes out of scope.

This method can not fail and has no return value.

=back

=head1 COPYRIGHT

Copyright (C) 2003, ActiveState Corporation.  All Rights Reserved.

=cut
