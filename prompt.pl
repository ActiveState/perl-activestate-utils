#!perl -w

use lib "./lib";
use ActiveState::Prompt qw(prompt yes);
use Data::Dump qw(dump);

dump(prompt("Foo?"));
dump(prompt("Foo?", ""));
dump(prompt("Foo?", "a"));
dump(prompt("Foo?", default => "a", use_default => 1));
dump(prompt("Foo?", default => "a", silent => 1));

dump(prompt("How old are you?", must_match => [1..100]));
dump(prompt("How old are you?",
	    must_match => qr/^\d\d?$/,
	    no_match_msg => "The answer must be a number less than 100",
	    trim_space => 1));

dump(yes("Do it?"));
dump(yes("Do it?", "yes"));
dump(yes("Do it?", 0));
dump(yes("Do it?", 1));

