#!perl -w

use Test qw(plan ok skip);
use strict;

plan tests => 40;
use ActiveState::Path qw(find_prog path_list realpath is_abs_path abs_path join_path rel_path unsymlinked);

use Config qw(%Config);
use File::Spec::Functions qw(catfile file_name_is_absolute);
use File::Basename qw(dirname);

$ENV{PATH} .= "$Config{path_sep}$Config{binexp}";  # make sure perldoc is on PATH

my $perldoc = find_prog("perldoc");
ok($perldoc);
ok(file_name_is_absolute($perldoc));
ok(is_abs_path($perldoc));
ok(find_prog($perldoc), $perldoc);

ok(!find_prog("/usr/bin"));
ok(!find_prog("notthere"));

ok(path_list());

my $t = realpath("t");
ok(file_name_is_absolute($t));
ok(is_abs_path($t));
ok(realpath("t/path.t"), catfile($t, "path.t"));
ok(!eval { realpath("notthere") });
ok($@ =~ /^The path 'notthere' is not valid/);

$t = abs_path("t");
ok(is_abs_path($t));
ok(abs_path("t/path.t"), "$t/path.t");

ok(realpath("t"), abs_path("t"));  # should be same since "t" is not a symlink

ok(join_path("t", "path.t"), catfile("t", "path.t"));
ok(join_path("t", "."), "t");
ok(join_path("t", ".."), ".");
ok(join_path("t", "../x"), "x");

my $root = ($^O eq "MSWin32") ? "C:\\" : "/";
ok(join_path($root, "foo"), catfile($root, "foo"));
ok(join_path($root, "."), $root);
ok(join_path($root, ".."), $root);
ok(join_path($root, "../.."), $root);
ok(join_path($root, "../../foo"), catfile($root, "foo"));

ok(rel_path($t, catfile($t, "path.t")), "path.t");
ok(rel_path($t, $t), ".");
ok(rel_path($t, dirname($t)), "..");

use Config;
if ($Config{d_symlink}) {
    my $dir = "xx-t$$";
    mkdir($dir, 0755) || die;
    mkdir("$dir/d", 0755) || die;
    mkdir("$dir/d/c", 0755) || die;

    symlink("b", "$dir/a");
    symlink("c", "$dir/b");
    symlink("d/c", "$dir/c");
    symlink("d/a", "$dir/d/a");
    symlink(".", "$dir/d/d");

    symlink("loop2", "$dir/loop1");
    symlink("loop1", "$dir/loop2");

    symlink("..", "$dir/d/back");
    symlink("does/not/exist", "$dir/d/dangling");

    my $dir_abs = abs_path($dir);

    ok(abs_path("$dir/a"), "$dir_abs/a");
    ok(realpath("$dir/a"), "$dir_abs/d/c");
    ok(unsymlinked("$dir/a"), "$dir/d/c");

    ok(!eval{unsymlinked("$dir/loop1")});
    ok($@ =~ /^symlink cycle/);

    ok(!eval{unsymlinked("$dir/d/a")});
    ok($@ =~ /^symlink resolve limit exceeded/);

    ok(unsymlinked("$dir/d/back"), $dir);
    ok(unsymlinked("$dir/d/back/d/back/d/back"), $dir);

    ok(realpath("$dir/d/back/d/back/d/back"), $dir_abs);
    ok(abs_path("$dir/d/back/d/back/d/back"), "$dir_abs/d/back/d/back/d/back");

    ok(eval { realpath("$dir/d/dangling") }, undef);
    ok($@ =~ /^Dangling symlink for/);

    use File::Path qw(rmtree);
    rmtree($dir, 1);
}
else {
    # the 1 is so old Test.pm's will accept this skip
    skip("no symlinks", 1) for 1..13;
}
