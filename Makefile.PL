require v5.6;
use ExtUtils::MakeMaker;

my $DIR = [];
unless ($^O eq "MSWin32") {
    push @$DIR, "File-Atomic";
}

WriteMakefile(
    NAME	 => 'ActiveState::Utils',
    VERSION	 => '1.22',
    DIR		 => $DIR,
    PREREQ_PM    => { 'Time::HiRes' => 1 },
    ($] ge '5.006' ? (
	AUTHOR	 => 'ActiveState Corporation',
	ABSTRACT => 'Internal ActiveState utility modules',
    ) : ()),
);
