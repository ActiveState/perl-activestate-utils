#!/usr/bin/perl -w

use strict;
use Test;
use ActiveState::File::Atomic;
use File::Path;

plan tests => 610;

my $tmpdir  = "rotate-$$";
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
sub lstmp {
    opendir(my $DIR, $tmpdir) or die "can't opendir $tmpdir: $!";
    return my @files = sort grep { $_ !~ /^\.\.?$/ } readdir($DIR);
}
sub rmtmp {
    for (lstmp()) {
	my $f = "$tmpdir/$_";
	unlink($f) or die "Can't unlink $f: $!"
    }
}

mkpath($tmpdir);
END { rmtree($tmpdir) }

ok(lstmp(), 0); # start with zero files

# Start with a simple case: single digit rotations:
my $f    = 'something';
my $file = mkfile($f);
{
    my $at = ActiveState::File::Atomic->new($file, writable => 1, rotate => 4);
    my $wfh = $at->tempfile;
    print $wfh "Hello, world\n";
    $at->commit_tempfile;

    my @f = lstmp();
    ok(@f, 2);
    ok($f[0], $f);
    ok($f[1], "$f.1");
}

for (1 .. 10) {
    my $at = ActiveState::File::Atomic->new($file, writable => 1, rotate => 4);
    my $wfh = $at->tempfile;
    while (defined($_ = $at->readline)) { print $wfh "blah: $_" }
    $at->commit_tempfile;
}
{
    my @f = lstmp();
    ok(@f, 5);
    ok($f[0], $f);
    ok($f[$_], "$f.$_") for (1 .. 4);
}

rmtmp();

# Try two digits, with backup_ext => ','.
$f    = 'life';
$file = mkfile($f);
for my $n (1 .. 100) {
    my $at = ActiveState::File::Atomic->new($file,
	writable	=> 1,
	backup_ext	=> ',',
	rotate		=> "42",
    );
    $at->commit_string('');
    my $exp_n = $n > 42 ? 42 : $n;
    my @s = lstmp();
    ok(@s, 1 + $exp_n);
    ok($s[-1], sprintf("$f,%02i", $exp_n));
}

rmtmp();

# Now let's do more digits :)
my $rotate = 555;
$f    = 'big';
$file = mkfile($f);
for my $n (1 .. 100) {
    my $at = ActiveState::File::Atomic->new($file, writable => 1, rotate => $rotate);
    my $w = $at->tempfile;
    while (defined($_ = $at->readline)) { print $w $_ }
    print $w "$n\n";
    $at->commit_tempfile;
    my @f = lstmp();
    ok(@f, 1 + $n);
    ok($f[0], $f);
    # This takes *way* too long. It's basically $n**2 tests. Don't want that.
    # ok($f[$_], sprintf("$f.%03i", $_)) for (1 .. $n);
    # Instead, we'll just make sure the top one exists.
    ok($f[-1], sprintf("$f.%03i", $n));

    # Now make sure the file contains the right stuff:
    my $txt = do {
	open(my $TMP, $file) or die "can't open $file: $!";
	local $/;
	<$TMP>
    };
    ok($txt, join("\n", 1 .. $n) . "\n");
}

# vim: ft=perl
