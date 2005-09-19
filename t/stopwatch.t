#!perl -w

BEGIN {
    if ($^O eq "MSWin32") {
	print "1..0 # Skipped: ActiveState::StopWatch test does not work on Windows\n";
	exit 0;
    }
}

use Test qw(plan ok);
plan tests => 6;

use strict;
use ActiveState::StopWatch;

my $w = start_watch();

sleep(1);

my $times = stop_watch($w);
#print "$times\n";

ok($times =~ /^r=1[.s]/);

ok(ActiveState::StopWatch::real_time($w) >= 1);

sleep(1);

my $times2 = read_watch($w);
#print "$times2\n";
ok($times, $times2);

start_watch($w);

$times = ActiveState::StopWatch::read_watch($w);
#print "$times\n";

ok($times =~ /^r=1[.s]/);

ok($times !~ /cu=/);

# do some work in a child
my $cuser = (times)[2];
do {
    system("$^X -e '\$a = q() for 1 .. 1e5'");
} until (times)[2] - $cuser > 0.01;


use ActiveState::StopWatch qw(read_watch);

$times = read_watch($w);
#print "$times\n";

ok($times =~ /cu=/);
