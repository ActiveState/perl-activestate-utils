#!/usr/bin/perl -w

use strict;
use Config;

# Find the tests:
my @tests;
my $ok = opendir(my $TESTS, "t");
if ($ok) {
    while (my $t = readdir($TESTS)) {
	next unless $t =~ /\.t$/;
	next unless -f "t/$t";
	push @tests, "t/$t";
    }
    @tests = sort @tests;
    closedir($TESTS) or die "can't closedir 't': $!";
}

open(my $MF, "> Makefile") or die "can't write Makefile: $!";

print $MF <<HEADER;
# Generated from $0. Do not make changes!!!

CC = $Config{cc}
AR = $Config{ar}
LD = $Config{ld}
CFLAGS = $Config{ccflags} -I. -g
LIB_EXT = $Config{lib_ext}
OBJ_EXT = $Config{obj_ext}
MAKE = $Config{make}
PERL = $Config{perlpath}
RANLIB = $Config{ranlib}
TEST_VERBOSE = 0

HEADER

print $MF <<'!NO!SUBS!';
LIBTARGET = libatomicfile$(LIB_EXT)

all: $(LIBTARGET)

clean ::
	rm -f $(LIBTARGET) *.o

distclean: clean
	rm -f Makefile

purge: distclean

$(LIBTARGET): atomicfile$(OBJ_EXT) atomicdir$(OBJ_EXT) common$(OBJ_EXT)
	$(AR) cr $@ atomicfile$(OBJ_EXT) atomicdir$(OBJ_EXT) common$(OBJ_EXT)
	$(RANLIB) $@

atomicfile$(OBJ_EXT): atomicfile.c atomicfile.h atomictype.h

atomicdir$(OBJ_EXT): atomicdir.c atomicdir.h atomictype.h

common$(OBJ_EXT): common.c

.c.o:
	$(CC) -o $@ $(CFLAGS) -c $*.c

!NO!SUBS!

if (@tests) {
    print $MF <<"!SUBS!";
test: tests
	\$(PERL) -e 'use Test::Harness qw(&runtests \$\$verbose); \$\$verbose=\$(TEST_VERBOSE); runtests \@ARGV' ${ \"@tests" }

!SUBS!
    for (@tests) {
	(my $c_file = $_) =~ s/\.t$/\.c/;
	next unless -f $c_file;
	(my $exe = $_) =~ s/\.t$//;
	print $MF <<TEST for @tests;
tests :: $exe

$exe: $c_file \$(LIBTARGET)
	\$(CC) -o \$\@ \$(CFLAGS) $c_file \$(LIBTARGET)

clean ::
	rm -f $exe
TEST
    }
}
else {
    print $MF <<'!NO!SUBS!';
test: $(LIBTARGET)
	@echo "No tests defined"
!NO!SUBS!
}


close($MF) or die "can't write Makefile: $!";
