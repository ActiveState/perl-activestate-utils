#!/usr/bin/perl -w

use strict;
use Test;
use ActiveState::File::Atomic;
use File::Path;

my $tmpdir  = "errors-$$";
sub mkfile {
    my $basename = shift;
    my $callback = shift;
    my $f = "$tmpdir/$basename";
    open my $FILE, "> $f" or die "can't write $f: $!";
    print $FILE @_;
    close $FILE;
    &$callback($f) if $callback;
    return $f;
}

mkpath($tmpdir);
{
    my $pid = $$;
    END { return unless $pid == $$; rmtree($tmpdir) }
}

plan tests => 10;

# Invalid constructor argument:
{
    my $at = eval { ActiveState::File::Atomic->new('foo', nosuchfoo => 42) };
    ok($@, qr{Unknown option 'nosuchfoo'});
}

# File not found errors:
{
    my $at = eval { ActiveState::File::Atomic->new("$tmpdir/not-there") };
    ok($@, qr{Can't open file '$tmpdir/not-there': });
}

# You try to open a readonly file writable:
{
    my $f = mkfile('readonly', sub { chmod 0400, $_[0] });
    my $at = eval { ActiveState::File::Atomic->new($f, writable => 1) };
    ok($@, ''); # XXX we want this?
    unlink $f;
}

# You can't lock the file. This test is hard to judge correctly:
{
    my $f = mkfile('locktest');
    my $pid = fork;
    die "can't fork: $!" unless defined $pid;
    if ($pid == 0) {
	my $at = ActiveState::File::Atomic->new($f, writable => 1);
	sleep 10;
	exit;
    }
    else {
	sleep 1; # give the child time to grab the lock
	my $at;
	$at = eval { ActiveState::File::Atomic->new($f, nolock => 1) };
	ok($@, '');
	$at = eval { ActiveState::File::Atomic->new($f, timeout => 1) };
	ok($@, '');
	$at = eval { ActiveState::File::Atomic->new($f, writable => 1, timeout => 1) };
	ok($@, qr{Can't lock file '$f': });
    }
}

# You try to commit a file before calling write_handle():
{
    my $f = mkfile('nowrite');
    my $at = ActiveState::File::Atomic->new($f);
    eval { $at->commit_tempfile };
    ok($@, qr/commit_tempfile\(\) called before tempfile\(\)/);
}

# The temporary file is deleted between write_handle() and commit():
# XXX we can't test this anymore, because we no longer expose the name of the
# temporary file to Perl. I suppose it's better that way :-)
if (0) {
    my $f = mkfile('gone');
    my $at = ActiveState::File::Atomic->new($f, writable => 1);
    $at->tempfile;
    unlink $at->_tempfile(0); # not a public method
    eval { $at->commit_tempfile };
    ok($@, qr/tempfile disappeared before commit\(\)/);
}

# The original file is deleted between new() and commit(). Make sure
# this does *not* cause an error when backup_ext and rotate are disabled:
{
    my $f = mkfile('gone2');
    my $at = ActiveState::File::Atomic->new($f, writable => 1);
    unlink $f;
    eval { $at->commit_string('') };
    ok($@, '');
}
# ... but it should fail if backup_ext is on:
{
    my $f = mkfile('gone3');
    my $at = ActiveState::File::Atomic->new($f, writable => 1, backup_ext => '.bak');
    unlink $f;
    eval { $at->commit_string('') };
    ok($@, qr/error creating the backup file/);
}
# ... and it should fail if rotate is on:
{
    my $f = mkfile('gone4');
    my $at = ActiveState::File::Atomic->new($f, writable => 1, rotate => 4);
    unlink $f;
    eval { $at->commit_string('') };
    ok($@, qr/error creating the backup file/);
}

# The other errors require interrupting the actual commit() call, which is
# quite difficult. That's why they're not tested.

# vim: ft=perl
