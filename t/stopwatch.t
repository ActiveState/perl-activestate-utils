#!perl -w

print "1..5\n";

use ActiveState::StopWatch;

my $w = start_watch();

sleep(1);

my $times = stop_watch($w);
print "$times\n";

print "not " unless $times =~ /^r=1\./;
print "ok 1\n";

print "not " unless ActiveState::StopWatch::real_time($w) > 1;
print "ok 2\n";

sleep(1);

start_watch($w);

$times = ActiveState::StopWatch::read_watch($w);
print "$times\n";

print "not " unless $times =~ /^r=1\./;
print "ok 3\n";

print "not " if $times =~ /cu=/;
print "ok 4\n";

# do some work in a child
my $cuser = (times)[2];
do {
    system("$^X -e '\$a = q() for 1 .. 1e5'");
} until (times)[2] - $cuser > 0.01;


use ActiveState::StopWatch qw(read_watch);

$times = read_watch($w);
print "$times\n";

print "not " unless $times =~ /cu=/;
print "ok 5\n";
