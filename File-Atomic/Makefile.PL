use ExtUtils::MakeMaker;

my $lib;
for (qw(atomicfile ../../lib/atomicfile)) {
    if (-d $_) {
	$lib = $_;
	last;
    }
}
die "Can't locate atomicfile C library" unless $lib;

WriteMakefile(
    NAME		=> 'ActiveState::File::Atomic',
    VERSION_FROM	=> 'Atomic.pm',
    INC			=> " -I$lib ",
    MYEXTLIB		=> "$lib/libatomicfile\$(LIB_EXT)",
    depend		=> { 'Atomic$(OBJ_EXT)' => "$lib/libatomicfile\$(LIB_EXT)" },
);

sub MY::postamble { <<END }

$lib/libatomicfile\$(LIB_EXT): $lib/atomicfile.h $lib/atomicfile.c
	cd $lib && \$(FULLPERL) Makefile.PL && \$(MAKE)

END
