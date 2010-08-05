#!perl -w

use Test;
plan tests => 6;

use ActiveState::Handy qw(stringf);

my %fruit = (
    'a' => "apples",
    'b' => "bannanas",
    'g' => "grapefruits",
    'm' => "melons",
    'w' => "watermelons",
);

ok(stringf("I like %a, %b, and %g, but not %m or %w.", %fruit),
   "I like apples, bannanas, and grapefruits, but not melons or watermelons.");


my %args = (
    d => sub { use POSIX; POSIX::strftime($_[0], localtime) },
);

my $s = stringf("It is %{%M:%S}d right now, on %{%A, %B %e}d.", %args);
print "# $s\n";
ok($s, qr/^It is \d\d:\d\d right now, on .* \d+\.\z/);

ok(stringf("!%5d!%-5d!%5.5d", d => 42), "!   42!42   !   42");
ok(stringf("!%5d!%-5d!%5.5d", d => 1234567), "!1234567!1234567!12345");
ok(stringf("%p%%", p => 42), "42%");
ok(stringf("%t%n"), "\t\n");
