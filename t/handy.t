print "1..46\n";

use ActiveState::Handy qw(add cat iso_date run xml_esc xml_clean ceil shell_quote);
use Errno;

$| = 1;

print "not " unless cat("MANIFEST") =~ m,ActiveState/Handy,;
print "ok 1\n";

print "not " unless iso_date(2000,1,1) eq "2000-01-01";
print "ok 2\n";

print "not " unless iso_date(1011985293) eq "2002-01-25";
print "ok 3\n";

run("\@echo ok 4");

run("-perl", "-e", 'print "ok 5\n"; exit 1');

eval {
   run("perl -e 'exit 42'");
};
print "not " unless $@ && $@ eq "Command exits with 42:\n  perl -e 'exit 42'\n  stopped at @{[__FILE__]} line @{[__LINE__-2]}\n";
print "ok 6\n";

eval {
   local $SIG{__WARN__} = sub {};  # suppress warning about failed exec
   run("not-there i hope");
};
$! = Errno::ENOENT;
print "not " unless $@ && $@ eq "Command \"not-there\" failed: $!:\n  not-there i hope\n  stopped at @{[__FILE__]} line @{[__LINE__-3]}\n";
print "ok 7\n";

print "not " unless xml_esc("<>") eq "&lt;>";
print "ok 8\n";

print "not " unless add() == 0 && add(1) == 1 && add(1,1) == 2 &&
	            add(1..5) == 15;
print "ok 9\n";

print "not " unless xml_clean("") eq '';
print "ok 10\n";

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
#use Data::Dump qw(dump); print dump(\@ceil), "\n";
my $i = 11;
while (@ceil) {
    my $k = shift(@ceil);
    my $v_expected = shift(@ceil);
    my $v = ceil($k);
    unless ($v == $v_expected) {
	print "# ceil($k): Expected '$v_expected', got '$v'\n";
	print "not ";
    }
    print "ok $i\n";
    ++$i;
}

print "not " unless shell_quote("a") eq "a";
print "ok 41\n";

print "not " unless shell_quote("") eq qq("");
print "ok 42\n";

print "not " unless shell_quote("a", "b", "a b") eq qq(a b "a b");
print "ok 43\n";

print "not " unless join(":", shell_quote("a", "b", "a b")) eq qq(a:b:"a b");
print "ok 44\n";

if ($^O eq "MSWin32") {
    my @args = ("a", "b", "a b", "\\\\\" \" \\\\");
    shell_quote(@args);
    print "not " unless join(":", @args) eq qq(a:b:"a b":"\\\\\\\\\\\" \\\" \\\\");
    print "ok 45\n";
}
else {
    my @args = ("a", "b", "a b", " \" \$ \` \\ ");
    shell_quote(@args);
    print "not " unless join(":", @args) eq qq(a:b:"a b":" \\" \\\$ \\` \\\\ ");
    print "ok 45\n";
}

my $cmd = shell_quote($^X, "t/echo-args.pl", "", "a", "\\", "'", '"', " ", "\\\\\"\\", '$PATH', '%PATH', '@PATH', '`foo`');
my $out = `$cmd`;
#print $out;
print "not " unless $out eq <<'EOT'; print "ok 46\n";
[]
[a]
[\]
[']
["]
[ ]
[\\"\]
[$PATH]
[%PATH]
[@PATH]
[`foo`]
EOT
