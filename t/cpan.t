#!perl -w

use strict;
use Test;

plan tests => 18;
use ActiveState::CPAN;
use File::Path qw(rmtree);

my $cpan = ActiveState::CPAN->new;

ok($cpan->author("GAAS"), "Gisle Aas <gisle\@ActiveState.com>");
ok(scalar(keys %{$cpan->authors}) > 6000);
ok($cpan->authors->{"GAAS"}, "Gisle Aas <gisle\@ActiveState.com>");

my $info = $cpan->package_info("authors/id/G/GA/GAAS/Data-Dump-1.08.tar.gz");
ok($info->{name}, "Data-Dump");
ok($info->{author}, "GAAS");
ok($info->{version}, "1.08");
ok($info->{maturity}, "released");
ok($info->{extension}, "tar.gz");

$info = $cpan->package_info("authors/id/N/NI/NI-S/Tk800.024.tar.gz");
ok($info->{name}, "Tk");
ok($info->{version}, "800.024");

my $next = $cpan->files_iter(matching => qr/libwww-perl-5\.837/);
my $count = 0;
while (my $f = $next->()) {
    print "$f\n";
    $count++;
}
ok($count, 3);


my $cache = "xx-cpan-cache.d";
die "Cache $cache exists" if -e $cache;
$cpan = ActiveState::CPAN->new(cache => $cache, verbose => 0);
# This test intentionally requests a distribution that is *only* on BackPAN
my $f = $cpan->get_file("authors/id/G/GA/GAAS/Digest-1.00.tar.gz");
print "$f\n";
ok($f);

{
my $cpan_without_backpan = ActiveState::CPAN->new(verbose => 0, backpan => undef);
# This test intentionally requests a distribution that is *only* on BackPAN
my $f = $cpan_without_backpan->get_file("authors/id/G/GA/GAAS/Digest-1.00.tar.gz");
ok($f, undef);
}

eval {
     $cpan->unpack("authors/id/G/GA/GAAS/libwww-perl-5.837.readme");
};
ok($@);

if ($^O eq "MSWin32") {
    skip("Depends on Unix shell stuff", 1) for 1..3;
}
else {
    my $d = $cpan->unpack("authors/id/G/GA/GAAS/libwww-perl-5.837.tar.gz");
    ok($d, "libwww-perl-5.837");
    ok(-f "libwww-perl-5.837/lib/LWP.pm");
    ok(rmtree("libwww-perl-5.837"));
}

$cpan->clear_cache;
ok(rmdir($cache));

