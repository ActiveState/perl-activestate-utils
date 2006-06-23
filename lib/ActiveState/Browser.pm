package PDK::Browser;

use strict;
use PDK::OSType qw(IS_WIN32 IS_DARWIN);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catdir catfile devnull file_name_is_absolute);
use ActiveState::Handy qw(shell_quote);
use ActiveState::Path qw(find_prog);

our $BROWSER = $ENV{PDK_BROWSER};
unless ($BROWSER) {
    if (IS_WIN32) {
	$BROWSER = "start %s";
    }
    elsif (IS_DARWIN) {
	$BROWSER = "/usr/bin/open %s";
    }
    else {
	for (qw(firefox mozilla netscape kfmclient gnome-open)) {
	    if (my $p = find_prog($_)) {
		$BROWSER = $p;
		last;
	    }
	}
	$BROWSER = [$BROWSER, "openURL"] if $BROWSER && $BROWSER =~ /kfmclient$/;
    }
}

our $HTML_DIR = $ENV{PDK_HTML_DIR};
unless ($HTML_DIR) {
    my $bin = defined(&PerlApp::Exe) ? dirname(PerlApp::Exe())
	                             : do { require FindBin; $FindBin::Bin };

    my $prefix = dirname($bin);
    if (IS_WIN32) {
	# XXX On Windows the RUNLIB is ./lib, on Unix ../lib
	# XXX It would be good to standardize on e.g. ../runlib
	# XXX to have the same relative path to the html directory
	# XXX from both the bin and the runlib directory.
	unless (-d catdir($prefix, "html")) {
	    my $dir = dirname($prefix);
	    $prefix = $dir if -d catdir($dir, "html");
	}
	$HTML_DIR = catdir($prefix, "html");
    }
    else {
	$HTML_DIR = catdir($prefix, "share/doc/HTML/en/pdk");
    }
}

sub can_open {
    my $url = shift;
    return 0 unless $BROWSER;
    return 1 if $url =~ /^(\w+):/;
    return !!eval { _resolve_file_url($url) };
}

sub _resolve_file_url {
    my $url = shift;
    my $frag;
    $frag = $1 if $url =~ s/#(.*)//;
    $url = catfile($HTML_DIR, $url) unless file_name_is_absolute($url);
    die "Help file $url not found\n" unless -f $url;
    $url = Win32::GetShortPathName($url) if IS_WIN32;
    $url = (IS_WIN32 ? "file:///" : "file://") . $url;
    $url .= "#$frag" if defined $frag;
    return $url;
}

sub _browser_cmd {
    my($url, $browser) = @_;
    $browser ||= $BROWSER || die "No browser specified";
    my $cmd;
    if (ref($browser)) {
	$cmd = shell_quote(@$browser, $url);
    }
    elsif ($browser =~ /%/) {
	$cmd = $browser;
	# substitute %s with url, and %% to %.
	$cmd =~ s/%([%s])/$1 eq '%' ? '%' : $url/eg;
    }
    else {
	$cmd = shell_quote($browser, $url);
    }
    #$cmd .= " 2>/dev/null 1>&2 " unless IS_WIN32;
    return $cmd;
}

sub open {
    my $url = shift;
    if (IS_WIN32 && eval { require Win32::Shell }) {
	my($document,$fragment) = $url =~ m,^(?:file:///?)?([^#]+)(?:#(.*))?$,;
	unless ($document =~ /^\w{2,}:/) {
	    $document = catfile($HTML_DIR, $document) unless file_name_is_absolute($document);
	    return if Win32::Shell::BrowseDocument($document, $fragment);
	}
	Win32::Shell::BrowseUrl($url);
	return;
    }

    $url = _resolve_file_url($url) unless $url =~ /^\w{2,}:/;
    die "Can't find any browser to use.  Try to set the PDK_BROWSER environment variable.\n"
	unless $BROWSER;

    system(_browser_cmd($url, $BROWSER));
}

1;

__END__

=head1 NAME

PDK::Browser - Interface to invoke the web-browser

=head1 SYNOPSIS

  use PDK::Browser;
  PDK::Browser::open("http://www.activestate.com");

=head1 DESCRIPTION

The PDK::Browser module provides an interface to make a web browser
pop up showing some URL or file.  The following functions are
provided:

=over

=item open( $url )

This will try to open up a web browser displaying the given URL.  The
function will croak if the $url can't be resolved or if no suitable
browser could be found.  The can_open() test can be used to protect
against such failure, but note that such a test is not race-proof.

If the $url is absolute it is passed directly to the browser.

If the $url is relative it is looked up relative to the F<html>
directory of the PDK installation.

=item can_open( $url )

Will return TRUE if we can invoke a browser for the given URL.  If the
URL is not to a local file, then this always returns TRUE, given that
a browser program was found.

=back

=head1 ENVIRONMENT

The PDK_BROWSER environment variable can be set to override what
browser to use.  The string C<%s> will be replaced with the URL to
open.  If no C<%s> is present the string is taken as a command to invoke
with the URL as the only argument.

The C<%s> template was inspired by the BROWSER environment variable
suggestion that appear quite dead; see
L<http://www.catb.org/~esr/BROWSER/>.  Note that the PDK_BROWSER is
B<not> a colon separated list.

=head1 BUGS

none.

=cut
