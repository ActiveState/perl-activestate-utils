#!perl -w

use Test qw(ok plan);

plan tests => 7;

use strict;
use ActiveState::Bytes qw(bytes_format);

ok(bytes_format(128), "128 bytes");
ok(bytes_format(1024), "1 KB");
ok(bytes_format(1024*1024), "1 MB");
ok(bytes_format(1024*1024*1024), "1 GB");

ok(bytes_format(12345), "12.1 KB");
ok(bytes_format(1234567890), "1.15 GB");
ok(bytes_format(7.5e12), "6.82 TB");
