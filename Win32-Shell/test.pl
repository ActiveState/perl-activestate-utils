use strict;
use warnings;

BEGIN { print "1..1\n" }
use ActiveState::Win32::Shell qw(BrowseDocument BrowseUrl);

print "ok 1\n";
exit;

my $url = "http://www.activestate.com/Products/Perl_Dev_Kit/";
print BrowseUrl($url);
exit;

my $document = 'C:\Program Files\ActiveState Perl Dev Kit 6.0\html\PerlApp.html';
my $fragment = 'perlapp_functions';
print BrowseDocument($document, $fragment);
