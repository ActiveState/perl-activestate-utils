#!/usr/bin/perl -w

use strict;
use Test;

plan tests => 21;

use ActiveState::Dir::Atomic;
use File::Path;

my $tmpdir  = "dir-$$";
END { rmtree($tmpdir) }

# Test that opening a nonexistent directory for read fails
eval { ActiveState::Dir::Atomic->new($tmpdir) };
ok($@, qr/^Can't open directory/);

# Test that opening an empty directory for read fails
mkdir($tmpdir) or die;
eval { ActiveState::Dir::Atomic->new($tmpdir) };
ok($@, qr/^Can't open directory/);
rmdir($tmpdir) or die;

{
    eval { ActiveState::Dir::Atomic->new($tmpdir, create => 1); };
    ok($@, qr/^Option create requires writable as well/);
    ok(!-e $tmpdir);

    my $at = ActiveState::Dir::Atomic->new($tmpdir, writable => 1, create => 1);
    ok(-e $tmpdir);
    undef $at;
    ok(-e $tmpdir);
    ok(!-e "$tmpdir/current");

    $at = ActiveState::Dir::Atomic->new($tmpdir, writable => 1, create => 1);
    $at->commit;
    ok(-e "$tmpdir/current");

    undef $at;
    $at = ActiveState::Dir::Atomic->new($tmpdir, writable => 1, create => 1);
    $at->commit("12345");

    undef $at;
    $at = ActiveState::Dir::Atomic->new($tmpdir, writable => 1);
    ok($at->version, "12345");
    $at->rollback(1);
}

# Make sure we don't leak any handles
my $fd1 = do { open(my $tmp, "< /dev/null") or die $!; fileno($tmp)};
for (1 .. 10) {
    ActiveState::Dir::Atomic->new($tmpdir, writable => 1);
}
my $fd2 = do { open(my $tmp, "< /dev/null") or die $!; fileno($tmp)};
ok($fd2, $fd1);

# Make sure we aren't holding onto the .lock file in read-only mode.
$fd1 = do { open(my $tmp, "< /dev/null") or die $!; fileno($tmp)};
$fd2 = do { my $q = ActiveState::Dir::Atomic->new($tmpdir);
	    open(my $tmp, "< /dev/null") or die $!; fileno($tmp)};
ok($fd2, $fd1);

# Make sure we get the expected number of subdirs
{
    my $at = ActiveState::Dir::Atomic->new($tmpdir, writable => 1);
    ok($at->scan, 3);
}

# Make sure that committing works:
{
    my $at = ActiveState::Dir::Atomic->new($tmpdir, writable => 1);
    my $scratch = $at->scratchpath;
    open (my $tag, "> $scratch/foo") or die "can't write $scratch/foo: $!";
    print $tag "$$\n";
    close $tag or die "can't close $scratch/foo: $!";
    $at->commit;
}
{
    my $at = ActiveState::Dir::Atomic->new($tmpdir);
    my $path;
    ok($at->current, 2);
    ok($path=$at->currentpath, "$tmpdir/2");
    ok(-f "$path/foo");
    ok(-s _);

    open(my $tmp, "$path/foo") or die "can't open $path/foo: $!";
    my $txt = do { local $/; <$tmp> };
    ok($txt, "$$\n");
}

# Now try rolling back to 1.
{
    my $at = ActiveState::Dir::Atomic->new($tmpdir, writable => 1);
    eval { $at->rollback(1) };
    ok($@, '');
}
{
    my $at = ActiveState::Dir::Atomic->new($tmpdir);
    my $path;
    ok($at->current, 1);
    ok($path=$at->currentpath, "$tmpdir/1");
    ok(!-f "$path/foo");
}

# vim: ft=perl
