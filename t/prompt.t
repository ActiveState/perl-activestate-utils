#!perl -w

# A quick non-interactive test

print "1..6\n";

use strict;
use ActiveState::Prompt qw(prompt yes);

$ActiveState::Prompt::USE_DEFAULT++ unless @ARGV && shift;

print "not " if yes("Foo?");
print "ok 1\n";

print "not " if yes("Foo?", 0);
print "ok 2\n";

print "not " unless yes("Foo?", "y");
print "ok 3\n";

print "not " unless yes("Foo?", 1);
print "ok 4\n";

print "not " unless prompt("Foo?") eq "";
print "ok 5\n";

print "not " unless prompt("Foo?", "foo") eq "foo";
print "ok 6\n";
