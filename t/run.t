#!perl -w

print "1..28\n";

use ActiveState::Run qw(run shell_quote decode_status);
use Errno;

$| = 1;

run("\@echo ok 1");

run("-$^X", "-e", "print qq(ok 2\\n); exit 1");

eval {
   run($^X . ' -e "exit 42"');
};
print "not " unless $@ && $@ eq "Command exits with 42:\n  $^X -e \"exit 42\"\n  stopped at @{[__FILE__]} line @{[__LINE__-2]}\n";
print "ok 3\n";

eval {
   local $SIG{__WARN__} = sub {};  # suppress warning about failed exec
   run("not-there i hope");
};
$! = Errno::ENOENT;
print "not " unless $@ && $@ eq ($^O eq "MSWin32" ? "Command exits with 1:" : "Command \"not-there\" failed: $!:") . "\n  not-there i hope\n  stopped at @{[__FILE__]} line @{[__LINE__-3]}\n";
print "ok 4\n";

print "not " unless shell_quote("a") eq "a";
print "ok 5\n";

print "not " unless shell_quote("") eq qq("");
print "ok 6\n";

print "not " unless shell_quote("a", "b", "a b") eq qq(a b "a b");
print "ok 7\n";

print "not " unless join(":", shell_quote("a", "b", "a b")) eq qq(a:b:"a b");
print "ok 8\n";

if ($^O eq "MSWin32") {
    my @args = ("a", "b", "a b", "\\\\\" \" \\\\");
    shell_quote(@args);
    print "not " unless join(":", @args) eq qq(a:b:"a b":"\\\\\\\\\\\" \\\" \\\\");
    print "ok 9\n";
}
else {
    my @args = ("a", "b", "a b", " \" \$ \` \\ ");
    shell_quote(@args);
    print "not " unless join(":", @args) eq qq(a:b:"a b":" \\" \\\$ \\` \\\\ ");
    print "ok 9\n";
}

my $cmd = shell_quote($^X, "t/echo-args.pl", "", "a", "\\", "'", '"', " ", "\\\\\"\\", '$PATH', '%PATH', '@PATH', '`foo`');
my $out = `$cmd`;
#print $out;
print "not " unless $out eq <<'EOT'; print "ok 10\n";
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

print "ok 11\n"; #dummy

$? = 0; # normal termination
print "not " if scalar decode_status;
print "ok 12\n";
my %s = decode_status($?);
print "not " if !$s{WIFEXITED} or $s{WEXITSTATUS} or $s{WIFSIGNALED}
                or $s{WIFSTOPPED} or $s{WCOREDUMP};
print "ok 13\n";

$? = 3 << 8;
print "not " unless decode_status eq "exits with 3";
print "ok 14\n";
%s = decode_status($?);
print "not " if !$s{WIFEXITED} or $s{WEXITSTATUS} != 3 or $s{WIFSIGNALLED}
                or $s{WIFSTOPPED} or $s{WCOREDUMP};
print "ok 15\n";

$? = 9 | 128; 
print "not " 
    unless decode_status eq "killed by signal 9 (core dumped)";
print "ok 16\n";
%s = decode_status($?);
print "not " if $s{WIFEXITED} or !$s{WIFSIGNALED} or $s{WTERMSIG} != 9 
                or $s{WIFSTOPPED} or !$s{WCOREDUMP};
print "ok 17\n";

$? = 2 << 8 | 0x7f;
print "not " 
    unless decode_status eq "stopped by signal 2";
print "ok 18\n";
%s = decode_status($?);
print "not " if $s{WIFEXITED} or $s{WIFSIGNALLED} or !$s{WIFSTOPPED}
                or $s{WSTOPSIG} != 2 or $s{WCOREDUMP};
print "ok 19\n";

use POSIX qw(WIFEXITED WEXITSTATUS WIFSIGNALED WTERMSIG WIFSTOPPED WSTOPSIG);

sub WXXX_ok {
    my($exitstatus,$termsig,$stopsig) = @_;
    my %s = decode_status;
    my $err;

    unless (!!$s{WIFEXITED} eq !!WIFEXITED($?)) {
        warn "WIFEXITED disagreement";
        $err++;
    }
    unless (!!$s{WIFSIGNALED} eq !!WIFSIGNALED($?)) {
        warn "WIFSIGNALED disagreement";
        $err++;
    }
    unless (!!$s{WISTOPPED} eq !!WIFSTOPPED($?)) {
        warn "WIFSTOPPED disagreement";
        $err++;
    }

    if ($s{WIFEXITED}) {
        if ($s{WEXITSTATUS} ne WEXITSTATUS($?)) {
            warn "WEXITSTATUS disagreement";
            $err++;
        }
        if (!defined $exitstatus) {
            warn "exited";
            $err++;
        }
        elsif ($exitstatus ne $s{WEXITSTATUS}) {
	    warn "unexpected existstatus";
	    $err++;
        }
    }
    elsif (defined $exitstatus) {
	warn "not exited";
	$err++;
    }

    if ($s{WIFSIGNALED}) {
        if ($s{WTERMSIG} ne WTERMSIG($?)) {
	    warn "WTERMSIG disagreement";
            $err++;
        }
        if (!defined $termsig) {
	    warn "signaled";
	    $err++;
        }
        elsif ($termsig ne $s{WTERMSIG}) {
	    warn "unexpected termsig";
            $err++;
        }
    }
    elsif (defined $termsig) {
	warn "not signaled";
        $err++;
    }

    if ($s{WIFSTOPPED}) {
        if ($s{WSTOPSIG} ne WSTOPSIG($?)) {
	    warn "WSTOPSIG disagreement";
            $err++;
        }
        if (!defined $stopsig) {
	    warn "stopped";
	    $err++;
        }
        elsif ($stopsig ne $s{WSTOPSIG}) {
	    warn "unexpected stopsig";
            $err++;
        }
    }
    elsif (defined $stopsig) {
	warn "not stopped";
        $err++;
    }

    return !$err;
}

if ($^O eq "MSWin32") {
    print "ok $_ # skip Windows is not POSIX enough\n" for 20 .. 28;
}
else {
system($^X, "-e", "exit 0");
print "not " unless WXXX_ok(0);
print "ok 20\n";

system($^X, "-e", "exit 1");
print "not " unless WXXX_ok(1);
print "ok 21\n";

system($^X, "-e", "exit 254");
print "not " unless WXXX_ok(254);
print "ok 22\n";

system($^X, "-e", "exit 255");
print "not " unless WXXX_ok(255);
print "ok 23\n";

system($^X, "-e", "exit 256");
print "not " unless WXXX_ok(0);
print "ok 24\n";

system($^X, "-e", "exit 257");
print "not " unless WXXX_ok(1);
print "ok 25\n";

system($^X, "-e", 'kill(15, $$); sleep(1)');
print "not " unless WXXX_ok(undef, 15);
print "ok 26\n";

system($^X, "-e", 'kill(9, $$); sleep(1)');
print "not " unless WXXX_ok(undef, 9);
print "ok 27\n";

system($^X, "-e", 'dump;');
print "not " unless WXXX_ok(undef, 6);
print "ok 28\n";

# XXX anyway to test the stop status?
}
