require v5.6;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME	 => 'ActiveState::Utils',
    VERSION	 => '1.19',
    PREREQ_PM    => { 'Time::HiRes' => 1 },
    ($] ge '5.006' ? (
	AUTHOR	 => 'ActiveState Corporation',
	ABSTRACT => 'Internal ActiveState utility modules',
    ) : ()),
);
