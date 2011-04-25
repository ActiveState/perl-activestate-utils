require v5.6;
use strict;
use warnings;

use Config qw(%Config);
use ExtUtils::MakeMaker;

my $DIR = [];
if ($^O eq "MSWin32") {
    push @$DIR, "Win32-Shell";
}
elsif (($ENV{AS_PERL_PRODUCT} || "") =~ /Enterprise/ && $] < 5.012) {
    push @$DIR, "File-Atomic" unless $^O eq "hpux" && $Config{ptrsize} == 8;
}

WriteMakefile(
    NAME	 => 'ActiveState::Utils',
    VERSION	 => '2.10',
    DIR		 => $DIR,
    PREREQ_PM    => { 'Time::HiRes' => 1 },
    ($] ge '5.006' ? (
	AUTHOR	 => 'ActiveState Corporation',
	ABSTRACT => 'Internal ActiveState utility modules',
    ) : ()),
);

sub MY::libscan {
    my($self, $path) =@_;
    return '' if $path =~ /\.pl$/;
    return '' if $path =~ /Utils\.pod$/;
    return '' if $path =~ /UTF8/;
    return '' if $^O eq "MSWin32" && $path =~ /Unix/;
    return '' if $path =~ /(P4|Distfiles|Install).pm$/;
    return $path;
}
