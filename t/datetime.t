#!perl -w

use strict;
use Test qw(plan ok);

BEGIN { plan tests => 18 }

use ActiveState::DateTime qw(is_leap_year days_in_month check_date month_name_short month_name_long);

ok(!is_leap_year(2005));
ok(is_leap_year(2008));

ok(days_in_month(2005, 1) == 31);
ok(days_in_month(2005, 2) == 28);
ok(days_in_month(2008, 7) == 31);
ok(days_in_month(2008, 2) == 29);

ok(check_date(2005, 1, 27));
ok(check_date(2005, 1, 31));
ok(!check_date(2005, 1, 33));
ok(!check_date(2005, 11, 31));
ok(!check_date(2005, 2, 29));
ok(check_date(2005, 2, 28));
ok(check_date(2008, 2, 29));
ok(!check_date(2008, 2, 30));
ok(!check_date(2005, 13, 6));
ok(!check_date(2004, 0, 4));

ok(month_name_short(2) eq 'Feb');
ok(month_name_long(2) eq 'February');
