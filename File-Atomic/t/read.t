#!/usr/bin/perl -w

use strict;
use ActiveState::File::Atomic;
use File::Path;
use Test;

plan tests => 6;

my $tmpdir  = "errors-$$";
sub mkfile {
    my $basename = shift;
    my $callback = shift;
    my $f = "$tmpdir/$basename";
    open my $FILE, "> $f" or die "can't write $f: $!";
    print $FILE @_;
    close $FILE;
    &$callback($f) if $callback;
    return $f;
}

mkpath($tmpdir);
END { rmtree($tmpdir) }

my $line1 = "H\n";
my $full  = <<'TEXT';
H
  E
    L
      L
        O

	W
      O
    R
  L
D
TEXT

my $f = mkfile('foobar', undef, $full);
{
    my $at = ActiveState::File::Atomic->new($f);
    ok($at->readline, $line1);
}
{
    my $at = ActiveState::File::Atomic->new($f);
    ok($at->slurp, $full);
}
{
    my $at = ActiveState::File::Atomic->new($f, writable => 1);
    ok($at->readline, $line1);
}
{
    my $at = ActiveState::File::Atomic->new($f, writable => 1);
    ok($at->slurp, $full);
}

$f = mkfile('foobar', undef, "");
{
    my $at = ActiveState::File::Atomic->new($f);
    ok($at->readline, undef);
}
{
    my $at = ActiveState::File::Atomic->new($f);
    ok($at->slurp, "");
}


# vim: ft=perl
