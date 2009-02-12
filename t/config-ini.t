#!perl -w

use strict;
use Test;
plan tests => 43, todo => [];

use ActiveState::Config::INI;

sub j { join("|", @_) }
sub slurp { my $f = shift; open(my $fh, "<", $f); local $/; scalar(<$fh>) }

my $conf;
$conf = ActiveState::Config::INI->new;
ok($conf);
ok($conf->content, "");
ok(! eval{ $conf->write } && $@);
ok(j($conf->sections), "");
ok($conf->property("foo", "bar"), undef);
ok(!$conf->have_property("foo", "bar"));

$conf->insert_line(2, "# this is a comment");
ok($conf->content, "\n\n# this is a comment\n");

ok($conf->property("Foo", "bar", "yes"), undef);
ok($conf->property("Foo", "bar"), "yes");
ok($conf->have_property("Foo", "bar"));

ok($conf->content, <<EOT);


# this is a comment
[Foo]
bar = yes
EOT

ok($conf->section_enabled("Foo", 0));
ok(!$conf->section_enabled("Foo"));
ok($conf->property_enabled("Foo", "bar", 0));
ok(!$conf->property_enabled("Foo", "bar"));

ok($conf->content, <<EOT);


# this is a comment
[-Foo]
# bar = yes
EOT

ok(!$conf->section_enabled("Foo", 1));
ok($conf->section_enabled("Foo"));
ok(!$conf->property_enabled("Foo", "bar", 1));
ok($conf->property_enabled("Foo", "bar"));

ok($conf->content, <<EOT);


# this is a comment
[Foo]
bar = yes
EOT

my $file = "xxtest-$$.ini";
die "$file already exist" if -e $file;

$conf->write($file);
ok(-f $file);

$conf = ActiveState::Config::INI->new($file);
ok($conf->property("Foo", "bar" => "no"), "yes");
ok($conf->property("Foo", "bar"), "no");
$conf->write;

ok(slurp($file), <<EOT);


# this is a comment
[Foo]
bar = no
EOT

ok(unlink($file));

my $buf = <<EOT;
# comment
   [  foo  ]
   a = 34
   b=23 ; just for the fun of it
#  c= 23
[ bar baz ]
EOT

$conf->content($buf);
ok($conf->content, $buf);
ok(j($conf->sections), "foo|bar baz");
ok(j($conf->properties("foo")), "a|b|c");
ok($conf->property("foo", "a"), 34);
ok($conf->property("foo", "b" => 66), 23);
ok($conf->property("foo", "x" => "y"), undef);
ok($conf->content, <<EOT);
# comment
   [  foo  ]
x = y
   a = 34
   b=66 ; just for the fun of it
#  c= 23
[ bar baz ]
EOT

$conf = ActiveState::Config::INI->new;
$conf->content("a=1");
ok($conf->property("", "a"), 1);
ok($conf->property("", foo => 42), undef);
ok($conf->property("", "foo"), 42);
ok($conf->property("a b c", "d e f" => "g h"), undef);
ok($conf->section_enabled("a b c", 0));

$conf->add_section("foo", <<EOT);
To foo or not to foo,
  ... that's the question
EOT

ok($conf->content, <<EOT);
foo = 42
a=1

[-a b c]
d e f = g h

# To foo or not to foo,
#   ... that's the question
[foo]
EOT

$conf->delete_section("a b c");
ok($conf->content, <<EOT);
foo = 42
a=1

# To foo or not to foo,
#   ... that's the question
[foo]
EOT

$conf->property("foo", "bar" => 42);
ok($conf->content, <<EOT);
foo = 42
a=1

# To foo or not to foo,
#   ... that's the question
[foo]
bar = 42
EOT

$conf->delete_section("");
$conf->property("foo", "baz" => 43);
ok($conf->content, <<EOT);
# To foo or not to foo,
#   ... that's the question
[foo]
baz = 43
bar = 42
EOT

$conf->delete_section("foo");
ok($conf->content, "");

$conf->content(<<EOT);
# this is a comment
# foo=42
[bar]
# bar = 23

[baz]
EOT
$conf->delete_section("bar");
ok($conf->content, <<EOT);
# this is a comment
# foo=42
[baz]
EOT
