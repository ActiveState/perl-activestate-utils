BEGIN {
    if ($^O eq "MSWin32") {
	print "1..0 # Skipped: ActiveState::Unix::Network does not work on Windows\n";
	exit 0;
    }
}

print "1..5\n";

use ActiveState::Unix::Network qw(interfaces mask_off num2ip);

my $ip = "10.9.8.7";
print "not " unless num2ip(unpack("N", pack("C*", split(/\./, $ip)))) eq $ip;
print "ok 1\n";

print "not " unless mask_off('192.168.3.45', '255.255.255.0') eq '192.168.3.0';
print "ok 2\n";

# this will fail unless you have an external IP
my @ifs = interfaces;
print "not " unless @ifs;
print "ok 3\n";

my $dup;
my %ips;
foreach my $i (@ifs) {
    print "# found IP=$i->{ip} netmask=$i->{netmask} subnet=$i->{subnet} "
          . "network_bits=$i->{network_bits}\n";
    $dup++ if $ips{$i->{ip}}++;
}
print(($dup ? "not " : ""), "ok 4\n");

my $if = $ifs[0];
print "not " unless mask_off($if->{ip}, $if->{netmask}) eq $if->{subnet};
print "ok 5\n";


