#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 14;

use ActiveState::Color qw(name_from_rgb hex_from_rgb rgb_from_name hsv_from_rgb rgb_from_hsv);

sub j { join(":", @_) }

ok(name_from_rgb(0, 0, 0), "black");
ok(name_from_rgb(1, 1, 1), "white");
ok(name_from_rgb(1, 1, 0), "yellow");
ok(hex_from_rgb(0, 0, 0), "#000000");
ok(hex_from_rgb(1, 1, 1), "#ffffff");

ok(j(rgb_from_name("yellow")), "1:1:0");
ok(j(rgb_from_name("#ffff00")), "1:1:0");

ok(j(hsv_from_rgb(0, 0, 0)), "0:0:0");
ok(j(hsv_from_rgb(1, 1, 1)), "0:0:1");
ok(j(hsv_from_rgb(1, 1, 0)), "60:1:1");

ok(j(rgb_from_hsv(0, 0, 0)), "0:0:0");
ok(j(rgb_from_hsv(0, 0, 1)), "1:1:1");
ok(j(rgb_from_hsv(60, 1, 1)), "1:1:0");

ok(name_from_rgb((rgb_from_hsv(176, .72, .83))), "#3bd4ca");
