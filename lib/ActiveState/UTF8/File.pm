package ActiveState::UTF8::File;

use strict;
use ActiveState::UTF8;
require IO::Handle;  # ensure print method works on real file handles

sub new {
    my $class = shift;
    my $fh = shift;

    bless {
	fh => $fh
    }, $class;
}

sub print {
    my $self = shift;
    my $s = shift;
    my $fh = $self->{fh};

    $fh->print(ActiveState::UTF8::encode_utf8($s));
}

1;

__END__

=head1 NAME

ActiveState::UTF8::File - Provide a thin UTF8 encoder wrapper around a filehandle

=head1 SYNOPSIS

 use ActiveState::UTF8::File;

 open($fh, ">myfile.txt");
 $utf8_fh = ActiveState::UTF8::File->new($fh);
 $utf8_fh->print("This will be encoded as UTF8\n");
 close($fh);

=head1 DESCRIPTION

The C<ActiveState::UTF8::File> wraps a file handle. When the print
method is called the text is automatically converted to UTF before
being written to a file.

=over

=item $fh2 = ActiveState::UTF8::File->new($fh)

The object constructor takes a file handle as argument. It will create
a new object that prints to that filehandle.

=item $fh2->print($string)

The print() will print the string given as argument to the wrapped
file handle encoded in UTF8.

=back

=cut
