#!perl -w

# This program demonstrates how menu input could be done
# using raw reads.

use Data::Dump qw(dump);
use Term::ReadKey qw(ReadMode ReadKey);


$| = 1;
print "Select? ";

ReadMode("raw");
my $max = 133;
my $n = 0;
while (1) {
    my $k = ReadKey(0);
    if ($k eq "\e") {
	# might begin an escape sequence, read rest of it
	while (defined(my $k2 = ReadKey(0.1))) {
	    $k .= "$k2";
	}
    }

    if ($k =~ /^\d$/) {
	my $new = $n * 10 + $k;
	if ($new < 1 || $new > $max) {
	    print "\a";
	}
	else {
	    print $k;
	    $n = $new;
	}
    }
    elsif ($k eq "\b" || $k eq "\177" || $k eq "\e[3~") {
	# delete
	if ($n) {
	    print "\b \b";
	    chop($n);
	    $n ||= 0;
	}
	else {
	    print "\a";
	}
    }
    elsif ($k eq "\e") {
	# escape
	$n = 0;
	last;
    }
    elsif ($k eq "\cc") {
	print "\n";
	ReadMode(0);
	die "Ctrl-C";
    }
    elsif ($k eq "\n") {
	last;
    }
    else {
	#print dump($k);
	print "\a";
    }
}
ReadMode(0);

print "\nn=$n\n";
