#!perl -w

use strict;
use Test qw(plan ok);

BEGIN { plan tests => 52 }

use ActiveState::Duration qw(dur_format_sm dur_format_iso dur_format_eng ago_eng dur_format_clock dur_parse);

ok(dur_format_sm(0), "0s");
ok(dur_format_sm(58), "1m");
ok(dur_format_sm(60*60), "1h");
ok(dur_format_sm(5_000_000), "8w");

ok(dur_format_iso(0), "PT0S");
ok(dur_format_iso(58), "PT1M");
ok(dur_format_iso(5_000_000), "P8W");

ok(dur_format_eng(58), "1 minute");
ok(dur_format_eng(2*61), "2 minutes");
ok(dur_format_eng(60*60), "1 hour");
ok(dur_format_eng(5_000_000), "8 weeks");

ok(ago_eng(0), "just now");
ok(ago_eng(-1), "1 second from now");
ok(ago_eng(1), "1 second ago");
ok(ago_eng(70), "1 minute and 10 seconds ago");
ok(ago_eng(70, 0.1), "1 minute and 10 seconds ago");
ok(ago_eng(70, 0.01), "1 minute and 10 seconds ago");
ok(ago_eng(70, 0.1, "first"), "1.2 minutes ago");
ok(ago_eng(70, 0.01, "first"), "1.17 minutes ago");
ok(ago_eng(70, 0.001, "first"), "1.167 minutes ago");
ok(ago_eng(5_000_000, 0.01), "8 weeks and 2 days ago");
ok(ago_eng(5_000_000, 0.001, "day"), "8 weeks and 1.9 days ago");

ok(dur_format_clock(0), "0:00:00");
ok(dur_format_clock(1.7), "0:00:01");
ok(dur_format_clock(60), "0:01:00");
ok(dur_format_clock(60*60+60+1), "1:01:01");
ok(dur_format_clock(60*60+60-1), "1:00:59");
ok(dur_format_clock(50000), "13:53:20");
ok(dur_format_clock(500000), "138:53:20");
ok(dur_format_clock(5000*60*60-1), "4999:59:59");
ok(dur_format_clock(-10), "-0:00:10");
ok(dur_format_clock(-60), "-0:01:00");

ok(dur_parse(undef), undef);
ok(dur_parse(""), undef);
ok(dur_parse("0"), 0);
ok(dur_parse("42"), undef);
ok(dur_parse("42s"), 42);
ok(dur_parse("42 secs"), 42);
ok(dur_parse("42 seconds"), 42);
ok(dur_parse("42 sekunder"), undef);
ok(dur_parse("-1h2m3s"), -62*60 - 3);
ok(dur_parse("just now"), 0);
ok(dur_parse("PT1M"), 60);
ok(dur_parse("1 second from now"), -1);
ok(dur_parse("1 minute and 10 seconds ago"), 70);
ok(dur_parse("1.2 minutes ago"), 72);
ok(dur_parse("negative 5 min"), -5 * 60);
ok(dur_parse("2 weeks"), 2*7*24*60*60);
ok(dur_parse("1 month"), undef);
ok(dur_parse("1 year"), undef);
ok(dur_parse("0:00:00"), 0);
ok(dur_parse("-1:02:03"), -62*60 - 3);
