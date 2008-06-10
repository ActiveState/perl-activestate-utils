use strict;
use Test::More;

# this array should be in ascending order of version number,
# so that comparing the array index of two versions
# should be equivalent to comparing their version.
my @versions =
 qw( 0.0.1
     0.1
     0.5
     0.10
     1.0a0
     1.0a1
     1.0alpha2
     1.0beta0
     1.0beta1
     v1.0b2
     1.0beta3
     1.0pre
     1.0pre1
     1.0rc
     1.0rc1
     1.0
     1.0a
     1.0b
     1.0p3
     1.0.4
     1.0p
     v1.1p0
     v1.1.0.1
     1.1-r2
     1.1-r3
     1.1p1
     1.1.1.1-r3
     1.1.1-r3
     1.1001_01
     1.1002
     1.1100
     2
     2.0.12d
     5.008002
     5.10.0
);

plan(tests => (@versions * @versions + 6));

require_ok( 'ActiveState::Version' );

foreach my $x (0 .. $#versions) {
    foreach my $y (0 .. $#versions) {
        is(ActiveState::Version::vcmp($versions[$x], $versions[$y]), $x <=> $y,
	   "($versions[$x] <=> $versions[$y]) = " . ($x <=> $y));
    }
}

is(ActiveState::Version::vcmp('1.a.2', '1.a.2'), 0, "1.a.2 == 1.a.3");
is(ActiveState::Version::vcmp('1.a.2', '1.a.3'), -1, "1.a.2 < 1.a.3");

is(ActiveState::Version::vcmp('1.2.3.4', '1.2.3-r4'), 0, "1.2.3.4 == 1.2.3-r4");
is(ActiveState::Version::vcmp('1.2.3.4', '1.2.3-r3'), 1, "1.2.3.4 > 1.2.3-r3");

ok(ActiveState::Version::vlt('', '5.55'), "'' < 5.55");
