#!perl -w

use strict;
use Test;
use ActiveState::Run qw(run_ex);
use Time::HiRes qw(time);

plan tests => 13;

run_ex(cmd => [$^X, "-le", "print 'ok 1'"]);  $Test::ntest++;
ok($?, 0);

my $before = time;
run_ex(
   cmd => [$^X, "-e", "select(undef, undef, undef, 1) while 1"],
   limit_time => 2,
   ignore_err => 1,
);
ok($?);
my $dur = time - $before;
print "\$dur = $dur\n";
ok(abs(2 - $dur) < 1.5);

my $tmp = "xx-$$";

$before = time;
run_ex(
   cmd => [$^X, "-le", "print qq(y) while 1"],
   output => $tmp,
   limit_output => 0.1,
   ignore_err => 1,
);
ok($?);
$dur = time - $before;
print "\$dur = $dur\n";
print "-s '$tmp' = ", -s $tmp, "\n";
ok($dur < 5);
ok(-s $tmp > 100_000);

run_ex(
    cmd => [$^X, "-le", 'print "ok $_" for 8..10'],
    output => $tmp,
    tee => 1,
);

$Test::ntest += 3;
ok($?, 0);
ok(-s $tmp, $^O eq "MSWin32" ? 19 : 16);

unlink($tmp);

require File::Basename;
run_ex(
    cmd => [$^X, "-le", "print 'ok @{[$Test::ntest++]}' if -f 'run_ex.t'"],
    cwd => File::Basename::dirname(__FILE__),
);
