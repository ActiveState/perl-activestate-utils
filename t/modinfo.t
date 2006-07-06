#!perl -w

use strict;
use Test qw(plan ok);
plan tests => 34;

use ActiveState::ModInfo qw(
    mod2fname fname2mod
    find_inc find_module
    open_inc open_module
    fixup_module_case
    list_modules
    parse_version
);

ok(mod2fname("Foo"), "Foo.pm");
ok(mod2fname("Foo::"), "Foo.pm");
ok(mod2fname("Foo::Bar"), "Foo/Bar.pm");
ok(mod2fname("Foo::Bar::"), "Foo/Bar.pm");
ok(fname2mod("Foo.pm"), "Foo");
ok(fname2mod("Foo/Bar.pm"), "Foo::Bar");
ok(fname2mod("Foo"), undef);

ok(find_module("File::Find"));
ok(find_module("strict"));
ok(!find_module("Foo::Bar"));

ok(find_inc("tainted.pl"));
ok(!find_inc("not-there.pl"));

my $fh = open_module("File::Find");
ok($fh);
my $found;
while (<$fh>) {
    $found++, last if /^package File::Find;/;
}
close($fh);
ok($found);
ok(open_module("strict"));
ok(!open_module("Foo::Bar"));

$fh = open_inc("strict.pm");
ok($fh);
$found = 0;
while (<$fh>) {
    $found++, last if /^package strict;/;
}
close($fh);
ok($found);

$fh = open_inc("tainted.pl");
$found = 0;
while (<$fh>) {
    $found++, last if /^sub tainted {/;
}
close($fh);
ok($found);

ok(fixup_module_case("Integer"), "integer");
ok(fixup_module_case("INTEGER"), "integer");
ok(fixup_module_case("integer"), "integer");
ok(fixup_module_case("file::find"), "File::Find");
ok(fixup_module_case("FILE::FIND"), "File::Find");
ok(fixup_module_case("Foo::Bar"), "Foo::Bar");

my %modules = list_modules();
ok(keys %modules > 200);
ok($modules{"File::Find"});
ok($modules{"File::Find"} =~ m,/File/Find\.pm\z,);
ok(!$modules{"Foo::Bar"});
ok($modules{integer});

%modules = list_modules(namespace => "File");
ok($modules{"File::Find"});
ok(!$modules{"integer"});

ok(parse_version("lib/ActiveState/ModInfo.pm"), "undef");
ok(parse_version("lib/ActiveState/Table.pm"), "0.02");

