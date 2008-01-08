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
     1.0beta
     1.0
     1.0a
     1.1
     1.1.0.1
     1.1001_01
     1.1002
     1.1100
     2
     2.0.12d
);

plan(tests => (@versions * @versions + 3));

require_ok( 'ActiveState::Version' );

foreach my $x (0 .. $#versions) {
    foreach my $y (0 .. $#versions) {
        is(ActiveState::Version::vcmp($versions[$x], $versions[$y]), $x <=> $y,
	   "($versions[$x] <=> $versions[$y]) = " . ($x <=> $y));
    }
}

is(ActiveState::Version::vcmp('1.a.2', '1.a.2'), 0, "1.a.2 == 1.a.3");
is(ActiveState::Version::vcmp('1.a.2', '1.a.3'), -1, "1.a.2 < 1.a.3");
