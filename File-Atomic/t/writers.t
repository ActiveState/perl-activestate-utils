#!/usr/bin/perl -w

use strict;
use ActiveState::File::Atomic;

$| = 1;
print "1..1\n";

my $iters = 8;
my $file = "writers-$$";
unlink $file;

my %pids;
for (1 .. $iters) {
    my $pid = fork;
    die "fork failed: $!" unless defined $pid;
    if ($pid) {
	++$pids{$pid};
	next;
    }

    select(undef, undef, undef, rand 0.1);
    my $l = ActiveState::File::Atomic->new($file, writable => 1, create => 1);

    my $data = $l->slurp;
    $l->commit_string((defined $data ? $data : "") . "ok $$\n");
    exit;
}

for (1 .. $iters) {
    wait;
}

open(my $f, "<", $file) or die "can't open test file $file: $!";
while (<$f>) {
    chomp;
    s/^ok //;
    delete $pids{$_};
}
close $f;

my $del = 1;
if (%pids) {
    print "# Updates by the following pids were lost:\n";
    print "#\t$_\n" for keys %pids;
    print "not ";
    $del = 0;
}
print "ok 1\n";

unlink $file if $del;
