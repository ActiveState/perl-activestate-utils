#!/usr/bin/perl -w

use lib "./lib";
use ActiveState::Handy qw(run);

die "Usage: $0 <cmd> [<arg>...]\n" unless @ARGV;

run(@ARGV);

