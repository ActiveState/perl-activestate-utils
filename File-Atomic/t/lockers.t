#! perl -w

use strict;
use ActiveState::File::Atomic;

$| = 1;

my $iters = 50;
print "1..$iters\n";
my $file = "writers-$$";
my $parent = $$;
END { unlink $file if $parent == $$ }

open(my $F, ">$file") or die; close $F;  # touch

my %pids;
for (1 .. $iters) {
    my $pid = fork;
    die "fork failed: $!" unless defined $pid;
    if ($pid) {
        ++$pids{$pid};
        next;
    }

    my $l = ActiveState::File::Atomic->new($file, writable => 1);

    # should get safely reverted here

    exit;
}

for (1 .. $iters) {
    my $pid = wait;
    die "wait() failed: $!" if $pid == -1;
    if ($?) {
        print "not ok $_ # pid $pid returned status $?\n";
    }
    else {
        print "ok $_\n";
    }
}
