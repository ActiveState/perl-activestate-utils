use Test qw(plan ok);

plan tests => 46;

use ActiveState::Handy qw(add cat iso_date run xml_esc xml_clean ceil 
                          shell_quote decode_status);
$| = 1;

ok(cat("MANIFEST") =~ m,ActiveState/Handy,);

{
    local $ENV{TZ} = 'UTC';
    ok(iso_date(2000,1,1), "2000-01-01");  
    ok(iso_date(1011985293), "2002-01-25");
}

ok(add(), 0);
ok(add(1), 1);
ok(add(1,1), 2);
ok(add(1..5), 15);


my @ceil = (
    1.5 => 2,
    11.1 => 12,
    -4.5 => -4,
    -3.5 => -3,
    -2.5 => -2,
    -1.5 => -1,
    -0.5 => 0,
    0   => 0,
    0.5 => 1,
    1.5 => 2,
    2.5 => 3,
    3.5 => 4,
    4.5 => 5,
    -4.0 => -4,
    -3.0 => -3,
    -2.0 => -2,
    -1.0 => -1,
    1.0 => 1,
    2.0 => 2,
    3.0 => 3,
    4.0 => 4,
    1.00000000000001 => 2,
    1 => 1,
    -1 => -1,
    '3.0' => 3,
    '4.0' => 4,
    '5.0' => 5,
    '-3.0' => -3,
    '-4.0' => -4,
    '-15.0' => -15,
);

while (@ceil) {
    my $k = shift(@ceil);
    my $v_expected = shift(@ceil);
    ok(ceil($k), $v_expected);
}

ok(xml_esc("<>"), "&lt;>");
ok(xml_clean(""), '');

# legacy functions should still work

ok(shell_quote("a", "b", "a b"), qq(a b "a b"));
run("\@echo hi");

$? = 3 << 8;
ok(decode_status, "exits with 3");

%s = decode_status($?);
ok($s{WIFEXITED});
ok($s{WEXITSTATUS}, 3);
ok(!$s{WIFSIGNALLED});
ok(!$s{WIFSTOPPED});
ok(!$s{WCOREDUMP});

