#!perl -w

use strict;
use Test;

BEGIN { plan tests => 19 }

use ActiveState::Indenter;
use ActiveState::Handy qw(cat cat_text);

my $file = "test-$$";
die "'$file' is in the way" if -e $file;

open(my $f, ">", $file) || die "Can't create '$file': $!";
my $i = ActiveState::Indenter->new($f);

ok($i->line_width, 70);
ok($i->indent_offset, 4);
ok($i->line, 1);

$i->print("A\n");
ok($i->line, 2);
$i->over;
$i->print("B\n");
$i->back;
$i->print("B\nC\n");
$i->over;
$i->print("A\nB\n");
$i->over;
$i->print("A(");
ok($i->column, 10);
$i->over_cur;

ok($i->depth, 3);

for ("a" .. "z") {
    $i->print("$_");
    if ($_ ne "z") {
       	$i->print(",");
	$i->soft_space;
    }
}
$i->print(")\n");
$i->back;
$i->print("B(<<EOT)\n");
$i->over_abs(0);
$i->print("Hello world!\nThis is a multiline string\n");
$i->print("EOT\n");
$i->back;
$i->print("C()\n");
$i->back;
$i->print("C\n\nD\n");

ok($i->depth, 1);
ok($i->column, 0);

$i->back;
$i->print("D\n");

ok($i->depth, 0);


close($f);

my $expectedString = <<'EOT2';
A
    B
B
C
    A
    B
        A(a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u,
          v, w, x, y, z)
        B(<<EOT)
Hello world!
This is a multiline string
EOT
        C()
    C

    D
D
EOT2

ok(cat_text($file), $expectedString);
$expectedString =~ s/\n/\r\n/g if $^O eq 'MSWin32';
ok(cat($file), $expectedString);
unlink($file) || warn "Can't clean up '$file': $!";

# try indenter with object instead of filehandle
$i = ActiveState::Indenter->new(Accumulator->new);

ok($i->indent_offset(2), 4);
ok($i->indent_offset, 2);
ok($i->line_width(20), 70);
ok($i->line_width, 20);

$i->print("A\n");
$i->over;
$i->print("B\n");
$i->back;
$i->print("C\n");
$i->over(4);
for ("a" .. "z") {
    $i->print($_);
    $i->soft_space if $_ ne "z";
}
$i->print("\n");
ok($i->indent, 4);
$i->back;
ok($i->indent, 0);
ok($i->line, 7);

ok($i->handle->value, <<EOT);
A
  B
C
    a b c d e f g h i
    j k l m n o p q r
    s t u v w x y z
EOT


package Accumulator;

sub new {
    bless [], shift;
}

sub print {
    my $self = shift;
    push(@$self, @_);
}

sub value {
    my $self = shift;
    join("", @$self);
}

