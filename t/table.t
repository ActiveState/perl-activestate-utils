#!perl -w

use strict;
use Test qw(plan ok);

plan tests => 39;

use ActiveState::Table;

my $t = ActiveState::Table->new;
ok($t);
ok(ref($t), "ActiveState::Table");
ok($t->fields, 0);
ok($t->rows, 0);
ok($t->as_csv, "\n");

$t->add_row({ a => 1});
ok($t->fields, 1);
ok($t->rows, 1);
ok(j($t->fields), "a");
ok(j(map j(@$_), $t->rows), "1");
ok($t->as_csv, "a\n1\n");

$t->add_row({ a => 2, b => 1});
ok($t->fields, 2);
ok(j($t->fields), "a:b");
ok($t->as_csv, <<EOT);
a,b
1,NULL
2,1
EOT

$t->add_row({});
$t->add_row({Box => 45});
ok($t->as_csv, <<EOT);
a,b,Box
1,NULL,NULL
2,1,NULL
NULL,NULL,NULL
NULL,NULL,45
EOT
ok($t->as_box, <<EOT);
+------+------+------+
| a    | b    | Box  |
+------+------+------+
| 1    | NULL | NULL |
| 2    | 1    | NULL |
| NULL | NULL | NULL |
| NULL | NULL | 45   |
+------+------+------+
  (4 rows)
EOT

ok($t->as_box(align => {b => "center", Box => "right"}), <<EOT);
+------+------+------+
| a    | b    | Box  |
+------+------+------+
| 1    | NULL | NULL |
| 2    |  1   | NULL |
| NULL | NULL | NULL |
| NULL | NULL |   45 |
+------+------+------+
  (4 rows)
EOT

ok($t->as_box(null => "", show_trailer => 0), <<EOT);
+---+---+-----+
| a | b | Box |
+---+---+-----+
| 1 |   |     |
| 2 | 1 |     |
|   |   |     |
|   |   | 45  |
+---+---+-----+
EOT

ok($t->as_box(null => "", show_header => 0, show_trailer => 0), <<EOT);
+---+---+----+
| 1 |   |    |
| 2 | 1 |    |
|   |   |    |
|   |   | 45 |
+---+---+----+
EOT

ok($t->as_csv(null => 0), <<EOT);
a,b,Box
1,0,0
2,1,0
0,0,0
0,0,45
EOT

ok($t->as_csv(null => "",
	      show_header => 0,
	      field_separator => ":",
	      row_separator => "#"),
   "1::#2:1:#::#::45#");

$t->add_row({a => 1, b => 2, Box => 3});
ok($t->fetchrow(0)->[0], 1);
ok($t->fetchrow(0)->[2], undef);
ok(j(map {defined($_) ? $_ : "undef"} $t->fetchrow(0)), "1:undef:undef");
ok(j($t->fetchrow(4)), "1:2:3");
ok($t->fetchrow(5), undef);
ok($t->fetchrow_arrayref(0)->[0], 1);
ok($t->fetchrow_arrayref(0)->[2], undef);
ok($t->fetchrow_arrayref(5), undef);
ok($t->fetchrow_hashref(0)->{a}, 1);
ok($t->fetchrow_hashref(0)->{b}, undef);
ok($t->fetchrow_hashref(0)->{c}, undef);
ok(j(sort keys %{$t->fetchrow_hashref(0)}), "Box:a:b");
ok($t->fetchrow_hashref(5), undef);

$t = ActiveState::Table->new;
$t->add_field("b", "a");
ok(j($t->fields, "b:a"));
ok($t->as_csv, "b,a\n");
ok($t->as_csv(show_header => 0), "");
$t->add_row({ a => "a,b" });

ok($t->as_csv, <<EOT);
b,a
NULL,a,b
EOT

$t = ActiveState::Table->new;
$t->add_row({a => 10, b => 1});
$t->add_row({a => 8, b => 3});
$t->add_row({a => 9});
$t->sort(sub { $a->[0] <=> $b->[0] });
ok($t->as_csv, <<EOT);
a,b
8,3
9,NULL
10,1
EOT
$t->sort(sub { no warnings 'uninitialized'; $b->[1] <=> $a->[1] });
ok($t->as_csv, <<EOT);
a,b
8,3
10,1
9,NULL
EOT

sub j { join(":", @_) }
