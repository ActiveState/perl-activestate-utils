#!perl -w

use Test qw(plan ok);
use strict;

plan tests => 7;
use ActiveState::Path qw(find_prog path_list realpath);

use File::Spec::Functions qw(catfile file_name_is_absolute);

ok(find_prog("perldoc"));
ok(file_name_is_absolute(find_prog("perldoc")));
ok(!find_prog("notthere"));

my $t = realpath("t");
ok(file_name_is_absolute($t));
ok(realpath("t/path.t"), catfile($t, "path.t"));
ok(!eval { realpath("notthere") });
ok($@ =~ /^The path 'notthere' is not valid/);
