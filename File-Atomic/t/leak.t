#!/usr/bin/perl -w

use strict;
use Test;
use ActiveState::File::Atomic;
use File::Path;

my $tmpdir  = "leak-$$";
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
END { rmtree($tmpdir) }

plan tests => 1;

# Make sure that after opening and closing a file, the next open is the same
# file descriptor:
my $f = mkfile('leaky');
my ($fd1, $fd2);
$fd1 = do { open(my $tmp, "< /dev/null") or die $!; fileno($tmp)};
for (1 .. 10) {
    my $at = ActiveState::File::Atomic->new($f, writable => 1);
    $at->tempfile; # create a temp file
}
$fd2 = do { open(my $tmp, "< /dev/null") or die $!; fileno($tmp)};
ok($fd1, $fd2);

# vim: ft=perl
