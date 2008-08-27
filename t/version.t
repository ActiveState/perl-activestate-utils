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
     5.000alpha1
     5.000alpha10
     5.000beta1
     5.000beta3
     5.000gamma
     5.000
     5.000a
     5.000m
     5.001
     5.002gamma
     5.002delta
     5.002
     5.003_97
     5.003_97j
     5.005_50
     5.6.1-TRIAL1
     5.6.1-TRIAL2
     5.6.1
     5.6.2-RC1
     5.6.2
     5.008002
     5.10.0
);

plan(tests => (@versions * @versions + 5 + 12 + 8));

use ActiveState::Version qw(vcmp vlt vnorm vnumify);

foreach my $x (0 .. $#versions) {
    foreach my $y (0 .. $#versions) {
        is(vcmp($versions[$x], $versions[$y]), $x <=> $y,
	   "($versions[$x] <=> $versions[$y]) = " . ($x <=> $y));
    }
}

is(vcmp('1.a.2', '1.a.2'), 0, "1.a.2 == 1.a.3");
is(vcmp('1.a.2', '1.a.3'), -1, "1.a.2 < 1.a.3");
is(vcmp('1.2.3.4', '1.2.3-r4'), 0, "1.2.3.4 == 1.2.3-r4");
is(vcmp('1.2.3.4', '1.2.3-r3'), 1, "1.2.3.4 > 1.2.3-r3");
ok(vlt('', '5.55'), "'' < 5.55");

is(vnorm(undef), 'v0', 'vnorm tests');
is(vnorm(""), 'v0');
is(vnorm("0.1alpha"), "v0.0.600");
is(vnorm("1.1a2"), "v1.0.602");
is(vnorm("1.1rc2"), "v1.0.902");
is(vnorm("1.1rc3"), "v1.0.903");
is(vnorm("1.1a"), 'v1.1.1');
is(vnorm("5.0102"), "v5.1.2");
is(vnorm("0.2802_01"), "v0.28.2.1");
is(vnorm("5.005_02"), "v5.5.2");
is(vnorm("5.010000"), "v5.10.0");
is(vnorm("5.001002003004"), "v5.1.2.3.4");

use version qw(qv);

is(vnumify(undef), 0, 'vnumify tests');
is(vnumify(""), 0);
is(vnumify("0"), 0);
is(vnumify("3.3"), "3.3");
is(vnumify("3.3.3"), "3.003003");
is(vnumify(qv("3.3")), "3.003000");
is(vnumify(version->new("3.3")), "3.300");
is(vnumify("foo"), "0.000");
