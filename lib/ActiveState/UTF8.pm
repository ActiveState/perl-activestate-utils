package ActiveState::UTF8;

use strict;
use base 'Exporter';
use Carp qw(croak);

our @EXPORT_OK = qw(encode_utf8 decode_utf8 encode_rfc2047 maybe_decode_utf8);

# Encode a string of Latin-1 1 byte chars to UTF8.
sub encode_utf8 {
    my $s = shift;
    if ($s) {
	$s =~ s/([\x80-\xFF])/sprintf("%c%c", 0xC0 | (ord($1) >> 6), 0x80 | (ord($1) & 0x3F))/ge;
    }
    return $s;
}

# Verify that a string is valid utf8 encoded data. The regexp was
# ripped from String::Multibyte::UTF8
sub is_valid_utf8 {
   my $s = shift;
   $s =~ s/\G			# stop at first non-match
            (?:[\x00-\x7F]
             | [\xC2-\xDF][\x80-\xBF]
             | [\xE0]     [\xA0-\xBF][\x80-\xBF]
             | [\xED]     [\x80-\x9F][\x80-\xBF]
             | [\xE1-\xEC][\x80-\xBF][\x80-\xBF]
             | [\xEE-\xEF][\x80-\xBF][\x80-\xBF]
             | [\xF0]     [\x90-\xBF][\x80-\xBF][\x80-\xBF]
             | [\xF1-\xF3][\x80-\xBF][\x80-\xBF][\x80-\xBF]
             | [\xF4]     [\x80-\x8F][\x80-\xBF][\x80-\xBF]
	    )
          //gx;
   return length($s) == 0;
}

# Decode a string of UTF8 encoded characters to Latin-1.
sub decode_utf8 {
    my $s = shift;

    if ($s) {
	croak "Invalid UTF8 encoding" unless is_valid_utf8($s);
	croak "Cannot handle UTF character beyond 255" if $s =~ /[\xC4-\xFF]/;
	$s =~ s/([\xC0-\xC3])([\x80-\xBF])/chr(((ord($1) & 0x1F) << 6) | (ord($2) & 0x3F))/ge;
    }
    return $s;
}

# Attempts to decode UTF-8, if that fails it returns original text
sub maybe_decode_utf8 {
    my $text = shift;
    my $rc = eval { decode_utf8($text) };
    return $@ ? $text : $rc;
}

# Wrap the whole string in 2047 encoding
sub _encode_region {
    my $s = shift;
    return $s unless $s =~ /[\x80-\xFF]/;
    # ord($1) >= 0x80 ? sprintf("=%X=%X", 0xC0 | (ord($1) >> 6), 0x80 | (ord($1) & 0x3F)):
    $s =~ s/([()<>@,;:\"\/\[\]?.= \x80-\xFF])/sprintf("=%X",ord($1))/ge;
    return "=?ISO-8859-1?Q?$s?=";
}

# Encode highbit characters as per rfc2047
sub encode_rfc2047 {
    my $s = shift;

    # If it has no highbit chars, no encoding is needed
    return $s unless $s =~ /[\x80-\xFF]/;

    my @hunks = split(/([\x80-\xFF]+ *)/, $s);
    my $accum = "";

    foreach (@hunks) {
	$accum .= _encode_region($_);
    }

    return $accum;

#    $s =~ s/([()<>@,;:\"\/\[\]?.= \x80-\xFF])/ord($1) >= 0x80 ? sprintf ("=%X=%X", 0xC0 | (ord($1) >> 6), 0x80 | (ord($1) & 0x3F)):sprintf("=%X",ord($1))/ge;
#    return "=?utf8?q?$s?=";
}

1;

__END__

=head1 NAME

ActiveState::UTF8 - Encoding and decoding character encodings

=head1 SYNOPSIS

 use ActiveState::UTF8 qw(encode_utf8 decode_utf8 maybe_decode_utf8);
 print "The string $str is UTF8 encoded.\n";
 $decoded = decode_utf8($str);
 print "The string $decoded is Latin-1 encoded.\n";
 $re_encoded = encode_utf8($decoded);
 print "The string $re_encoded is now UTF8 encoded, again.\n";

=head1 DESCRIPTION

The C<ActiveState::UTF8> module currently provides functions for
decoding UTF8 encoded strings into Latin-1 encoding and encoding
Latin-1 strings into UTF8 encoding.

=over

=item $s2 = decode_utf8( $s1 )

Decode a string from UTF8 to Latin-1.

$s1 must be encoded in UTF8. decode_utf8 will croak with an error if it
is not properly encoded. decode_utf8 will croak if the ord() of any
character in $s1 is greater than 255 (i.e. not a valid Latin-1
character).

=item $s2 = encode_utf8( $s1 )

Encode a Latin-1 encoded string to UTF8.

=item $s2 = maybe_decode_utf8( $s1 )

Decode a string from UTF8 to ISO-8859-1.

This function uses decode_utf8 to decode a UTF8 string in the Latin-1
range to ISO-8859-1.  However, if $s1 is not valid UTF-8 in the Latin-1
range, it returns $s1 unmodified and does not croak.

=back

=cut
