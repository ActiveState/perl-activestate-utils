package ActiveState::Version;

use strict;

our $VERSION = 1.1;

use base 'Exporter';
our @EXPORT_OK = qw(vcmp vge vgt vle vlt veq);

=head1 NAME

ActiveState::Version - Utility functions for version comparison

=head1 SYNOPSIS

 use ActiveState::Version qw(vgt veq vcmp);

 my $x = "0.9.9_beta";
 my $y = "0.10";
 my $z = "0.1";

 print "$x is ", (vgt($x, y) ? "greater" : "less or equal"), "than $y.\n";
 print "$y and $z are ", (veq($y, $z) ? "" : " not "), "equal.\n";

 my @sorted = sort { vcmp($a, $b) } ($x, $y, $z);

 print "The newest version is $sorted[-1].\n";

=head1 DESCRIPTION

Handy utilities for uniform version comparison across various
ActiveState applications.

Provides C<vcmp>, C<vge>, C<vgt>, C<vle>, C<vlt>, C<veq>, all
of which perform comparisons equivalent to the similarly named
perl operators.

=cut

sub vge ($$) { return (vcmp(shift, shift) >= 0); }
sub vgt ($$) { return (vcmp(shift, shift) >  0); }
sub vle ($$) { return (vcmp(shift, shift) <= 0); }
sub vlt ($$) { return (vcmp(shift, shift) <  0); }
sub veq ($$) { return (vcmp(shift, shift) == 0); }

sub vcmp ($$) {
    my($v1, $v2) = @_;

    return undef unless defined($v1) && defined($v2);

    # can we compare the version numbers as floats
    # return $v1 <=> $v2 if $v1 =~ /^\d+\.\d+$/ && $v2 =~ /^\d+\.\d+$/;

    # assume dotted form
    for ($v1, $v2) {
        s/^v//;
	# Turn 5.010001 into 5.10.1
	if (/^(\d+)\.(\d\d\d)(\d\d\d)$/) {
	    $_ = join('.', $1, $2, $3);
	    s/\.0+(\d+)/.$1/g;
	}
    }
    my @a = split(/[-_.]/, $v1);
    my @b = split(/[-_.]/, $v2);

    for (\@a, \@b) {
	# The /-r\d+/ suffix if used by PPM to denote local changes
	# and should always go into the 4th part of the version tuple.
	# As an extension, we will just strip the 'r' if the version
	# already has 4 or more parts.
	if ($_->[-1] =~ /^r(\d+)$/) {
	    pop @$_;
	    push @$_, 0 while @$_ < 3;
	    push @$_, $1;
	    next;
	}

        my $num;
        if ($_->[-1] =~ s/([a-z])$//) {
            my $a = $1;
            if ($_->[-1] eq "" || $_->[-1] =~ /^\d+$/) {
                $num = ord($a) - ord('a') + 1;
            }
            else {
                $_->[-1] .= $a;
            }
        }

        if (!defined($num) && $_->[-1] =~ s/(a|alpha|b|beta|p|patch|pre|rc|RC)(\d*)$//) {
            my $kind;
            ($kind, $num) = (lc $1, $2);
            $num ||= 0;
            my $offset = {
               a => 400,
               alpha => 400,
               b => 300,
               beta => 300,
	       p => 0,
	       patch => 0,
               pre => 200,
               rc => 100,
            };
	    die unless defined $offset->{$kind};
	    $num -= $offset->{$kind};
        }

        if (defined $num) {
            if (length($_->[-1])) {
                push(@$_, $num);
            }
            else {
                $_->[-1] = $num;
            }
        }
    }

    # { local $" = '.'; print "$v1=@a $v2=@b\n"; }
    while (@a || @b) {
        my $a = @a ? shift(@a) : 0;
        my $b = @b ? shift(@b) : 0;
        unless ($a =~ /^-?\d+$/ && $b =~ /^-?\d+$/) {
            next if $a eq $b;
            return undef;

        }
        if (my $cmp = $a <=> $b) {
            return $cmp;
        }
    }
    return 0;
}

1;
