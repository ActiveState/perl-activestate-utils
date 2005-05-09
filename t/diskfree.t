#!perl -w

BEGIN {
    if ($^O eq "MSWin32") {
	print "1..0 # Skipped: ActiveState::Unix::DiskFree does not work on Windows\n";
	exit 0;
    }
}

use strict;
use Test qw(plan ok);

BEGIN { plan tests => 5 }

use ActiveState::Unix::DiskFree qw(df);

my $df = df(".");
#use Data::Dump; Data::Dump::dump($df);
ok($df);
ok($df->{size} > 10 * 1024 * 1024);  # assume all disk are > 10 MB these days
ok($df->{size} >= $df->{free} + $df->{used});

$df = eval { df("/not-there") };
ok($df, undef);
ok($@ =~ /failed/);
