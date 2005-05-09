BEGIN {
    if ($^O eq "MSWin32") {
	print "1..0 # Skipped: ActiveState::Unix::Pw does not work on Windows\n";
	exit 0;
    }
}

use strict;
use ActiveState::Unix::Pw qw(useradd userdel usermod groupadd groupdel su);
use Test qw(ok plan);

BEGIN { plan tests => 11 }

my %opts = (_norun=>1);

my %groupadd = (
        gid=>777,
        unique=>1,
        group=>'pw_group',
);

my %useradd = (
        home=>'/home/pw_user_test',
        comment=>'test user - delete',
        create_home=>1,
        group=>'pw_group',
        user=>'pw_user',
        uid=>1234,
);
my %useradd2 = (
        home=>'/home/pw_user_test',
        comment=>'test user - delete',
        create_home=>1,
        group=>[qw(0 pw_group2 pw_group3)],
        user=>'pw_user',
);
my %useradd3 = (
        home=>'/home/pw_user_test',
        comment=>'test user - delete',
        create_home=>1,
        group=>[undef ,"pw_group2"],
        user=>'pw_user',
);

my %userdel = (
        remove_home=>1,
        user=>'pw_user',
);

my %usermod = (
        home => '/some/place/new',
        user => 'pw_user',
);

my %usermod2 = (
        home => '/some/place/new',
        login => 'new_user',
        user => 'pw_user',
);

my %groupdel = (
        group=>'pw_group',
);

my %su = (
        user=>'monkey',
        command=>'/bin/foo --bar',
);

my %su2 = (
        user=>'monkey',
        command=>'/bin/foo --bar',
        login=>1,
);

my %su_silent = (
        user=>'monkey',
        command=>'/bin/foo --bar',
        silent => 1,
);

if ($^O eq 'aix') {
    ok(scalar groupadd(%groupadd,%opts),'/usr/bin/mkgroup id=777 pw_group');
    ok(scalar useradd(%useradd,%opts),'/usr/bin/mkuser "gecos=test user - delete" home=/home/pw_user_test groups=pw_group pw_user');
    ok(scalar useradd(%useradd2,%opts),'/usr/bin/mkuser "gecos=test user - delete" home=/home/pw_user_test groups=0,pw_group2,pw_group3 pw_user');
    ok(scalar useradd(%useradd3,%opts),'/usr/bin/mkuser "gecos=test user - delete" home=/home/pw_user_test groups=pw_group2 pw_user');
    ok(scalar userdel(%userdel,%opts),'/usr/sbin/rmuser pw_user');
    ok(scalar usermod(%usermod,%opts),'/usr/bin/chuser home=/some/place/new pw_user');
    eval {
        usermod(%usermod2,%opts);
    };
    ok($@ =~ /Not available on AIX/);
    ok(scalar groupdel(%groupdel,%opts),'/usr/sbin/rmgroup pw_group');
    ok(scalar su(%su,%opts), '/usr/bin/su monkey "-c /bin/foo --bar"');
    ok(scalar su(%su2,%opts), '/usr/bin/su - monkey "-c /bin/foo --bar"');
    ok(scalar su(%su_silent,%opts), '@/usr/bin/su monkey "-c /bin/foo --bar"');
}
elsif ($^O eq 'freebsd') {
    ok(scalar groupadd(%groupadd,%opts),'/usr/sbin/pw groupadd -g 777 pw_group');
    ok(scalar useradd(%useradd,%opts),'/usr/sbin/pw useradd -c "test user - delete" -d /home/pw_user_test -m -u 1234 -g pw_group -n pw_user');
    ok(scalar useradd(%useradd2,%opts),'/usr/sbin/pw useradd -c "test user - delete" -d /home/pw_user_test -m -g 0 -G pw_group2,pw_group3 -n pw_user');
    ok(scalar useradd(%useradd3,%opts),'/usr/sbin/pw useradd -c "test user - delete" -d /home/pw_user_test -m -G pw_group2 -n pw_user');
    ok(scalar userdel(%userdel,%opts),'/usr/sbin/pw userdel -r -n pw_user');
    ok(scalar usermod(%usermod,%opts),'/usr/sbin/pw usermod -d /some/place/new -n pw_user');
    ok(scalar usermod(%usermod2,%opts),'/usr/sbin/pw usermod -d /some/place/new -l new_user -n pw_user');
    ok(scalar groupdel(%groupdel,%opts),'/usr/sbin/pw groupdel pw_group');
    ok(scalar su(%su,%opts), '/usr/bin/su monkey -c "/bin/foo --bar"');
    ok(scalar su(%su2,%opts), '/usr/bin/su - monkey -c "/bin/foo --bar"');
    ok(scalar su(%su_silent,%opts), '@/usr/bin/su monkey -c "/bin/foo --bar"');
}
else {
    ok(scalar groupadd(%groupadd,%opts),'/usr/sbin/groupadd -g 777 pw_group');
    ok(scalar useradd(%useradd,%opts),'/usr/sbin/useradd -c "test user - delete" -d /home/pw_user_test -m -u 1234 -g pw_group pw_user');
    ok(scalar useradd(%useradd2,%opts),'/usr/sbin/useradd -c "test user - delete" -d /home/pw_user_test -m -g 0 -G pw_group2,pw_group3 pw_user');
    ok(scalar useradd(%useradd3,%opts),'/usr/sbin/useradd -c "test user - delete" -d /home/pw_user_test -m -G pw_group2 pw_user');
    ok(scalar userdel(%userdel,%opts),'/usr/sbin/userdel -r pw_user');
    ok(scalar usermod(%usermod,%opts),'/usr/sbin/usermod -d /some/place/new pw_user');
    ok(scalar usermod(%usermod2,%opts),'/usr/sbin/usermod -d /some/place/new -l new_user pw_user');
    ok(scalar groupdel(%groupdel,%opts),'/usr/sbin/groupdel pw_group');
    if ($^O eq 'linux') {
        ok(scalar su(%su,%opts), '/bin/su monkey -c "/bin/foo --bar"');
        ok(scalar su(%su2,%opts), '/bin/su - monkey -c "/bin/foo --bar"');
        ok(scalar su(%su_silent,%opts), '@/bin/su monkey -c "/bin/foo --bar"');
    } else {
        ok(scalar su(%su,%opts), '/usr/bin/su monkey -c "/bin/foo --bar"');
        ok(scalar su(%su2,%opts), '/usr/bin/su - monkey -c "/bin/foo --bar"');
        ok(scalar su(%su_silent,%opts), '@/usr/bin/su monkey -c "/bin/foo --bar"');
    }
}

