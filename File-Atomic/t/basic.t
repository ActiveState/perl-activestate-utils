#!/usr/bin/perl -w

use strict;
use Test;

plan tests => 126;

use ActiveState::File::Atomic;
use File::Path;

my $tmpdir  = "basic-$$";
my $tmpfile = "$tmpdir/foo";
my $glob    = "$tmpdir/{.,}foo*";

mkpath($tmpdir);
END { rmtree($tmpdir) }

{
    eval { ActiveState::File::Atomic->new($tmpfile, create => 1); };
    ok($@, qr/^Option create requires writable as well/);
    ok(!-e $tmpfile);

    my $at = ActiveState::File::Atomic->new($tmpfile, writable => 1, create => 1);
    ok(!-e $tmpfile); # no commit() yet
    undef($at);
    ok(!-e $tmpfile); # no commit() yet

    $at = ActiveState::File::Atomic->new($tmpfile, writable => 1, create => 1);
    $at->commit_string("Hello, world\n");
    ok(-e $tmpfile);
}

print "# Testing readline, auto-close.\n";
for (1 .. 10) {
    my $at = ActiveState::File::Atomic->new($tmpfile);
    ok($at);
    my $txt = $at->readline;
    ok($txt, "Hello, world\n");
    eval { $at->tempfile };
    ok($@, qr/'\Q$tmpfile\E' was not opened writable/);
}

for (1 .. 10) {
    my $at = ActiveState::File::Atomic->new($tmpfile, writable => 1);
    ok($at);
    ok($at->readline, "Hello, world\n");
    my $wh = eval { $at->tempfile };
    ok($@, '');
    ok(ref($wh), 'GLOB');
    while (defined ($_ = $at->readline)) {
	print $wh "wh: $_" or die "error writing to tempfile: $!"
    }

    # There are 3 files: foo, .foo.lck, and .foo.RANDOM
    ok(@{[glob($glob)]}, 3);
    $at->close;
    ok(@{[glob($glob)]}, 1);
}

for (1 .. 10) {
    {
	my $at = ActiveState::File::Atomic->new($tmpfile, writable => 1);
	$at->tempfile;
    }
    ok(@{[glob($glob)]}, 1); # automatically called close()
}

for (1 .. 10) {
    my $at = ActiveState::File::Atomic->new($tmpfile, writable => 1);
    ok($at);
    my $wh = eval { $at->tempfile };
    while (defined($_ = $at->readline)) {
	print $wh "wh2: $_";
    }
    $at->commit_tempfile;
    ok(@{[glob($glob)]}, 1);
}

{
    open (my $T, "< $tmpfile") or die "can't open $tmpfile: $!";
    my $t = do { local $/; <$T> };
    my $exp = ("wh2: " x 10) . "Hello, world\n";
    ok($t, $exp);
}

# vim: ft=perl
