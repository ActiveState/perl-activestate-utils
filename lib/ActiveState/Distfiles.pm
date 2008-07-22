package ActiveState::Distfiles;

use strict;
use base 'Exporter';
our @EXPORT_OK = qw(distfiles_dir);

my @try = (
    "/net/nas/data/ppm/distfiles",
    "$ENV{HOME}/distfiles",
);

my $distfiles_dir;
for (@try) {
    $distfiles_dir = $_, last if -d $_;
}

unless ($distfiles_dir) {
    my $where = qx(p4 where //depot/main/contrib/distfiles/...);
    if ($where =~ m,^//depot/main/,) {
        $distfiles_dir = (split ' ', $where)[2];
        $distfiles_dir =~ s,/\.{3}\z,,;
        unless (-d $distfiles_dir) {
            require File::Path;
            File::Path::mkpath($distfiles_dir);
        }
    }
}

sub distfiles_dir {
    return $distfiles_dir;
}

1;
