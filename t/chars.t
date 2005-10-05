#!perl -w

BEGIN {
    print "1..0 # Skipped: Module not installed by default\n";
    exit;
}

use Test qw(ok plan);

plan tests => 9;

use strict;
use ActiveState::UTF8 qw(encode_utf8 decode_utf8 maybe_decode_utf8);

open(FH, "<t/data/invalid_utf8.txt");
my $invalid_utf8 = <FH>;
close(FH);

open(FH, "<t/data/gt255_char_utf8.txt");
my $gt255_char_utf8 = <FH>;
close(FH);

open(FH, "<t/data/utf8.txt");
my $utf8 = <FH>;
close(FH);

open(FH, "<t/data/latin1.txt");
my $latin1 = <FH>;
close(FH);

eval { print decode_utf8($invalid_utf8); };
ok($@ =~ /^Invalid UTF8 encoding/);

eval { decode_utf8($gt255_char_utf8); };
ok($@ =~ /^Cannot handle UTF character beyond 255/);

my $s1 = decode_utf8($utf8);
my $s2 = encode_utf8($latin1);
ok($s1 eq $latin1);
ok($s2 eq $utf8);

# Make sure they can handle undef strings
ok(not defined(decode_utf8));
ok(not defined(encode_utf8));
ok(not defined(maybe_decode_utf8));

my $s3 = maybe_decode_utf8($utf8);
my $s4 = maybe_decode_utf8($latin1);
ok($s3 eq $latin1);
ok($s4 eq $latin1);
