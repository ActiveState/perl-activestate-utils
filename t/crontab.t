#!/usr/bin/perl -w

BEGIN {
    if ($^O eq "MSWin32") {
	print "1..0 # Skipped: ActiveState::Unix::Crontab does not work on Windows\n";
	exit 0;
    }
}

use strict;
use Test qw(plan ok);

BEGIN { plan tests => 32 }

use ActiveState::Unix::Crontab qw(cron_list cron_add cron_install cron_cmds cron_parse cron_format cron_parse);

my $save = "crontab-$$";
my @save_list = cron_list();

open(my $f, ">", $save) || die "Can't create $save: $!";
print $f @save_list;
close($f) || die;

ok(cron_install());

ok(cron_list(), "");

ok(cron_add(cmd => "ls", comment => "Run 'ls' every minute"));
ok(cron_add(cmd => "wc -w", data => "foo\nbar\n", wday => 0, hour => 12));
ok(join(";", cron_cmds()), "ls;wc -w");

ok(cron_add(cmd => qq(mail -s "It's 10pm" joe),
	    wday => "1-5",
	    hour => 22,
	    min  => 0,
	    data => "Joe,\n\nWhere are your kids?\n"));


ok(cron_list(), <<EOT);
# Run 'ls' every minute
* * * * * ls
* 12 * * 0 wc -w%foo%bar%
0 22 * * 1-5 mail -s "It's 10pm" joe%Joe,%%Where are your kids?%
EOT

# Test cron_format() directly
ok(cron_format() =~ /^\#?\n\z/);
ok(cron_format(comment => ""), "# \n");
ok(cron_format(comment => " # foo"), " # foo\n");
ok(cron_format(comment => "foo"), "# foo\n");
ok(cron_format(env => "BAR"), "BAR=\n");
ok(cron_format(env => "BAR", value => "foo"), "BAR=foo\n");
ok(cron_format(cmd => "ls"), "* * * * * ls\n");
ok(cron_format(cmd => "ls", min => "5"),  "5 * * * * ls\n");
ok(cron_format(cmd => "ls", hour => "5"), "* 5 * * * ls\n");
ok(cron_format(cmd => "ls", mday => "5"), "* * 5 * * ls\n");
ok(cron_format(cmd => "ls", mon => "5"),  "* * * 5 * ls\n");
ok(cron_format(cmd => "ls", wday => "5"), "* * * * 5 ls\n");
ok(cron_format(cmd => "ls", min => "1", hour => 2, mday => 3, mon => 4, wday => 5), "1 2 3 4 5 ls\n");
ok(cron_format(cmd => "ls", enabled => 0), "#* * * * * ls\n");
ok(cron_format(cmd => "ls", data => "data\n%"), "* * * * * ls%data%\\%\n");

# Test cron_parse() directly
sub p {
    my %opts = cron_parse(@_);
    join(" ", map "$_=$opts{$_}", sort keys %opts);
}

ok(p("\n"), "");
ok(p("#foo"), "comment=#foo");
ok(p(" # foo"), "comment= # foo");
ok(p("FOO="), "env=FOO value=");
ok(p("FOO=34"), "env=FOO value=34");
ok(p("FOO=#34"), "env=FOO value=#34");
ok(p("* * * * * ls"), "cmd=ls enabled=1");
ok(p("#* * * * * ls"), "cmd=ls enabled=");
ok(p("1 2 3 4 5 ls \\%*%data%foo\n"), "cmd=ls %* data=data\nfoo enabled=1 hour=2 mday=3 min=1 mon=4 wday=5");

# restore things back as they where
system("crontab $save");
my @restored_list = cron_list();
if ("@restored_list" eq "@save_list") {
    unlink($save);
    ok(1);
}
else {
    warn "Can not restore crontab back the way it was.  Look in $save for backup.\n";
    ok(0);
}

