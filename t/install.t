#!perl -w

use strict;
use lib "./lib";

print "1..13\n";

use ActiveState::Install qw(install installed);
$ActiveState::Prompt::USE_DEFAULT = 1;

my $t = "test-$$";
die if -e $t;

# Clean up any old packages
system("rm -rf .packages");

# Try to install someting, this should work
install(pkg => "Test-Lib",
	ver => "0.1",
	files => { "lib" => "$t" },
	etc => ".",
	);

print "not " unless system("diff -r lib $t") == 0;
print "ok 1\n";

# A new install on top of it should not do much
print "not " unless install(pkg => "Test-Lib",
			    ver => "0.1",
			    files => { "lib" => "$t" },
			    etc => ".",
			   ) == 0;
print "ok 2\n";

# Let's remove a file and reinstall
unlink("$t/ActiveState/Install.pm") || warn;
unlink("$t/ActiveState/Handy.pm") || warn;
print "not " unless install(pkg => "Test-Lib",
			    ver => "0.1",
			    files => { "lib" => "$t" },
			    etc => ".",
			    config_files => { "lib/ActiveState/Handy.pm" => 1, },
			    verbose => 3,
			   ) == 2
			   and -e "$t/ActiveState/Install.pm"
			   and -e "$t/ActiveState/Handy.pm";
print "ok 3\n";

# done with it
system("rm -rf $t .packages");

# Try again, this time it should fail because a target is missing
eval {
    install(pkg => "Test-Lib",
	    ver => "0.1",
	    files => { "lib" => "$t", "zzz" => "x" },
	    etc => ".",
	   );
};
print $@;
print "not " unless $@;
print "ok 4\n";

print "not " if -e $t;
print "ok 5\n";

# Try configuration file feature, first make something we
# can try to install
die "apkg exists" if -e "apkg";

mkdir("apkg", 0755) || die;

my $lineno;
sub append_line {
    my $file = shift;
    open(my $f, ">>", $file) || die "Can't open $file: $!";
    print $f "line" . ++$lineno . "\n";
}

my %cfg;
for ("a".."f") {
    mkdir("apkg/$_", 0755) || die;
    append_line("apkg/$_/c1");
    append_line("apkg/$_/c2");
    $cfg{"apkg/$_/c1"} = 1;
    $cfg{"apkg/$_/c2"} = 2;
}

# and then add some extra files for good measure
append_line("apkg/foo");
system("chmod +x apkg/foo");
append_line("apkg/bar");
mkdir("apkg/empty_dir");

# Then try to install it
my @pkg = (pkg => "Test-Lib",
	   ver => "0.1",
	   files => { "apkg" => $t },
	   config_files => \%cfg,
	   etc => ".",
	   preserve_mtime => 1,
	  );
       
install(@pkg);

# edit some of the files
append_line("$t/a/c1");
append_line("$t/a/c2");

append_line("apkg/b/c1");
append_line("apkg/b/c2");

append_line("$t/c/c1");
append_line("$t/c/c2");
append_line("apkg/c/c1");
append_line("apkg/c/c2");

unlink("$t/d/c1");
unlink("$t/d/c2");
append_line("$t/d/c1");
append_line("$t/d/c2");

unlink("apkg/e/c1");
unlink("apkg/e/c2");
rmdir("apkg/e") || die;
delete $cfg{"apkg/e/c1"} || die;
delete $cfg{"apkg/e/c2"} || die;
append_line("$t/e/c1");
append_line("$t/e/c2");

append_line("apkg/f/c1");
append_line("apkg/f/c2");
unlink("$t/f/c1");
mkdir("$t/f/c1", 0755) || die;
append_line("$t/f/c1/foo");
unlink("$t/f/c2");
mkdir("$t/f/c2", 0755) || die;
append_line("$t/f/c2/foo");


unlink("apkg/bar");

# Try to reinstall on top of it
# Then try to install it
install(@pkg);

my $files = `cd $t && find . -print`;
$files = join("", sort split(/^/, $files));
#print $files;

print "not " unless $files eq <<'EOT'; print "ok 6\n";
.
./a
./a/c1
./a/c2
./b
./b/c1
./b/c2
./c
./c/c1
./c/c1.ppmsave
./c/c2
./c/c2.ppmdist
./d
./d/c1
./d/c2
./e
./e/c1.ppmdeleted
./e/c2.ppmdeleted
./empty_dir
./f
./f/c1
./f/c1.ppmsave
./f/c1.ppmsave/foo
./f/c2
./f/c2.ppmdist
./f/c2/foo
./foo
EOT

# XXX should also look into some of the files to make sure they
# XXX are updated properly.

#system("cd $t && diff -ru ../apkg .");

my $pkg = installed(pkg => "Test-Lib", etc => ".");
print "not " unless $pkg;
print "ok 7\n";

print "not " unless $pkg->files == 13;
print "ok 8\n";

print "not " if $pkg->changed("$t/foo");
print "ok 9\n";

mkdir("$t/p");
symlink("bobby", "$t/p/link");
install(pkg => "link",
	ver => "0.1",
	files => { "$t/p" => "$t/q" },
	etc => ".",
	);
print "not " unless -l "$t/q/link";
print "ok 10\n";

my $line = do {
    open(my $TXT, ".packages/link") || die;
    { local $/ = ""; <$TXT> }; # first paragraph
    <$TXT> # return first file
};
my ($md5, $conf, $file) = split ' ', $line;
print "not " if $md5 ne 'a9c4cef5735770e657b7c25b9dcb807b'; # md5_hex("bobby")
print "ok 11\n";
print "not " unless $conf == 0;
print "ok 12\n";
print "not " unless $file eq "$t/q/link";
print "ok 13\n";

# clean up all the mess
system("rm -rf apkg $t");
