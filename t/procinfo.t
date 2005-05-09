#!perl -w

BEGIN {
    if ($^O eq "MSWin32") {
	print "1..0 # Skipped: ActiveState::Unix::ProcInfo does not work on Windows\n";
	exit 0;
    }
}

use strict;
use Test;

BEGIN { plan tests => 15 }

use ActiveState::Unix::ProcInfo qw(proc_info);

unless (fork()) {
    exit 1;  # create a zoombie
}
sleep(1);

my $info = proc_info(root_pid => $$);
#use Data::Dump; print Data::Dump::dump($info), "\n";

ok($info);
ok($info->{$$});
ok($info->{$$}{children}, 2);
ok($info->{$$}{descendants} =~ /^(2|3)$/);
if ($^O eq "solaris" || $^O eq "hpux") {
    # These OSes truncate args, so we can't will not find
    # $0 in there when our path gets long enough.
    ok(length $info->{$$}{args});

    # On Solaris /usr/ucb/ps give full args, but that program
    # does not understand the -o option, so the ProcInfo
    # module can't really use it.  It is also not always
    # installed.
}
else {
    ok($info->{$$}{args} =~ /\Q$0/);
}
ok($info->{$$}{ppid});
ok($info->{$$}{rss});
ok($info->{$$}{vsz});
ok($info->{$$}{vsz} >= $info->{$$}{rss});

$| = 1; # ensure flushed buffers before we fork
ok(1);

my $pid = fork();
unless ($pid) {
    die "Fork failed: $!" unless defined $pid;
    # child
    fork();
    fork();
    sleep(2);
    exit;
}

$info = proc_info(root_pid => $pid);
#use Data::Dump; print Data::Dump::dump($info), "\n";
ok($info->{$pid});
ok($info->{$pid}{ppid}, $$);

# should be able to check process tree here, but Linux
# will classify some of them as threads.

$info = proc_info(root_args_match => qr/perl/);
#use Data::Dump; print Data::Dump::dump($info), "\n";
ok($info->{$$});  # should find this one

my @all_procs = proc_info();
ok(@all_procs);
shift(@all_procs) if $all_procs[0]{pid} == 0;  # (swapper) or sched

# init (pid=1) should always be there
ok($all_procs[0]{pid}, 1);
