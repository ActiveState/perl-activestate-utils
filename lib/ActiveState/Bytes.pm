package ActiveState::Bytes;

use strict;
use base 'Exporter';

our @EXPORT_OK = qw(bytes_format);

sub bytes_format {
    my $n = shift;

    return sprintf "%.3g TB", $n / (1024 * 1024 * 1024 * 1024)
	if $n >= 1024 * 1024 * 1024 * 1024;

    return sprintf "%.3g GB", $n / (1024 * 1024 * 1024)
	if $n >= 1024 * 1024 * 1024;

    return sprintf "%.3g MB", $n / (1024 * 1024)
	if $n >= 1024 * 1024;
    
    return sprintf "%.3g KB", $n / 1024
	if $n >= 1024;

    return "$n bytes";
}

1;

__END__

=head1 NAME

ActiveState::Bytes - Format byte quantities

=head1 SYNOPSIS

 use ActiveState::Bytes qw(bytes_format);
 print "The file is ", bytes_format(-s $file), " long.\n";

=head1 DESCRIPTION

The C<ActiveState::Bytes> module currently only provide a single
function.

=over

=item $str = bytes_format( $n )

This formats the number of bytes given as argument as a string using
suffixes like "KB", "GB", "TB" to make it concise.  The return value
is a string like one of these:

   128 bytes
   1.5 KB
   130 MB

Precision might be lost and there is currently no way to influence how
precise the result should be.  The current implementation gives no
more than 3 digits of precision.

=back

=head1 COPYRIGHT

Copyright (C) 2003 ActiveState Corp.  All rights reserved.

=head1 SEE ALSO

L<ActiveState::Duration>

=cut
