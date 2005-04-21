#!/usr/bin/perl -w

# miscellaneous routines for perforce
# not official, just hacks
# NeilK, Sept 2001

package ActiveState::P4;

use Carp;
use POSIX qw/strftime/;

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION %EXPORT_TAGS);
@ISA = qw(Exporter);
@EXPORT_OK = qw(
    p4_sync
    p4_refresh
    p4_sync_rev
    p4_sync_epochsecs
    p4_remove

    p4_add
    p4_edit
    p4_opened
    p4_delete
    p4_revert
    p4_integrate
    p4_resolve

    p4_submit

    p4_diff
    p4_diff2

    p4_where
    p4_fstat
    p4_files
    p4_dirs

    p4_changes
    p4_describe
    get_rev_range

    p4_info

    p4_exists

    p4_print

    p4d2p
);
%EXPORT_TAGS = (all => \@EXPORT_OK);

$ENV{'P4PORT'} ||= "scythe:1667";  # assuming ActiveState and one repository only. sue me. 

my $NUL = $^O eq 'MSWin32' ? '2>NUL' : '2>/dev/null';
my $PSEP = $^O eq 'MSWin32' ? '\\' : '/';

sub p4_cmd {
    my ($cmd) = @_;
    #warn "P4CMD<$cmd>";
    my $results;
    my $full_cmd = "p4 $cmd $NUL |";
    open my $pipe, $full_cmd or die "$full_cmd failed! -- $!";
    { local $/ = undef; $results = <$pipe> };
    close $cmd;
    return wantarray ? (split /^/m, $results) : $results;
}

sub p4_print {
    my %info;
    my $current;
    for my $spec (@_) {
	for (p4_cmd("print $spec")) {
	    if (m[^(//[^#]+)\#\d+\s+-\s+\w+\s+change\s+\d+\s+\(\w+\)]) {
		$current = $1;
		$info{$1} = '';
	    }
	    elsif ($current) {
		$info{$current} .= $_;
	    }
	}
    }
    wantarray ? %info : \%info;
}

sub p4_edit {
    for my $file (@_) {
	p4_cmd("edit $file");
    }
}

sub p4_add {
    for my $file (@_) {
	p4_cmd("add $file");
    }
}

sub p4_delete {
    for my $file (@_) {
	p4_cmd("delete $file");
    }
}

sub p4_revert {
    for my $file (@_) {
	p4_cmd("revert $file");
    }
}

sub p4_integrate {
    my ($from, $to, @opts) = @_;
    return p4_cmd("integrate @opts $from $to");
}

sub p4_resolve {
    my $optsref = shift;

    # Build up the list of options from the keys of the given $optsref hashref
    my $opts = join(' ', keys %{ $optsref });

    for my $file (@_) {
	p4_cmd("resolve $opts $file");
    }
}

sub p4_diff {
    my ($file, $rev1, $rev2) = @_;
    if (@_ == 1) {
	return p4_cmd("diff $file");
    }
    elsif (@_ == 2) {
	return p4_cmd("diff $file#$rev1");
    }
    else {
        return p4_cmd("diff $file#$rev1 $file#$rev2");
    }
}

sub p4_diff2 {
    my ($file1, $file2, @opts) = @_;
    return p4_cmd("diff2 @opts $file1 $file2");
}

sub p4d2p {
    my @patch;
    my $file;
    my $time = localtime(time);
    my $re1 = qr#^==== (//depot/.+?)\#\d+.* ====(?:\s+\w+)?$#;
    my $re2 = qr#^(\@\@.+\@\@|\*+)$#;
    while (@_) {
	my ($cur, $match);
	local $_ = shift @_;
	$cur = m/$re1/ ... m/$re2/;
	$match = $1;

	if ($cur) {
	    # while we are within range
	    if ($cur == 1) {
		$file = $match;
	    }
	    # emit the diff header when we hit last line
	    elsif ($cur =~ /E0$/) {
		my $f = $file;
		# unified diff
		if ($match =~ /^\@/) {
		    push @patch, "Index: $f\n";
		    push @patch, "--- $f.~1~\t$time\n";
		    push @patch, "+++ $f\t$time\n";
		}
		# context diff
		elsif ($match =~ /^\*/) {
		    push @patch, "Index: $f\n";
		    push @patch, "*** $f.~1~\t$time\n";
		    push @patch, "--- $f\t$time\n";
		}
	    }
	    # see if we hit another patch (i.e. previous patch was empty)
	    elsif (m/$re1/) {
		$match = $1;
	    }
	    # suppress all other lines in the header
	    else {
		next;
	    }
	}
	push @patch, $_;
    }
    @patch;
}

# where on this client is this p4 path?
sub p4_where {
    my $file = shift;
    my $which = shift;
    my $preserve = shift;
    $which = 2 unless defined $which;

    # Add a '/...' if you're looking for a directory. p4_where() will chomp it
    # for you.
    my ($results) = p4_cmd("where $file");
    chomp $results;
    #my ($depot_path, $client_path, $path) = split / / => $results;
    my @where = split / / => $results;
    $where[$which] =~ s/\Q$PSEP\E\.{3}$//
      unless $preserve;
    return $where[$which];
}

# returns a list of hashrefs if multiple found, or just one hashref
sub p4_fstat {
    my ($file, $rev) = @_;
    my $path = $file;
    defined($rev) and $path .= "#$rev";
    my $cmd = "fstat -s $path";
    my $results = p4_cmd($cmd);
    my @fstat;
    my $i = 0;
    for my $line (split /\n/, $results) {
        if ($line =~ /^$/) {
            $i++;
        } elsif ($line =~ /^\.\.\.\s+(\S+)\s+(.*)$/g) {
            $fstat[$i]{$1} = $2;
        } else {
            die "unexpected results: $line";
        }
    }

    return wantarray ? @fstat : $fstat[0];
}

sub p4_dirs {
    p4_cmd("dirs @_");
}

sub p4_files {
    if (ref($_[0]) eq "HASH") {
        my $opts = shift;
        if ($opts->{detailed}) {
            my @files = p4_cmd("files @_");
            my @detailed;
            foreach (@files) {
                next unless /^([^#]+)#(\d+) - (\w+) change (\d+) \((\w+)\)$/;
                push @detailed, { name => $1,
                                  rev => $2,
                                  action => $3,
                                  num => $4,
                                  type => $5,
                                };
            }
            return wantarray ? @detailed : \@detailed;
        }
    }
    p4_cmd("files @_");
}

sub p4_exists {
    my $file = shift;
    my @changes = p4_changes($file, 1);
    return @changes ? 1 : 0;
}

sub p4_rm_from_client {
    my ($file) = @_;
    p4_sync($file, 'none');
}

sub p4_sync {
    my ($file, $rev, @opts) = @_;
    p4_cmd("sync @opts $file" . (defined($rev) ? "#$rev" : ''));
}

sub p4_refresh {
    p4_cmd("refresh $_") for @_;
}

sub p4_sync_epochsecs {
    my ($file, $time, @opts) = @_;

    if (defined($time)) {
	my $date = strftime("%Y/%m/%d:%H:%M:%S", localtime($time));
	p4_sync_rev($file, $date, @opts);

    } else {
	p4_sync($file, undef, @opts);
    }
}

sub p4_sync_rev {
    my ($file, $date, @opts) = @_;

    if (defined($date)) {
	p4_cmd("sync @opts $file\@$date");

    } else {
	p4_sync($file, undef, @opts);
    }
}

sub p4_remove {
    my ($file) = @_;

    # Don't try this without a valid file name, please.  Using 'p4 sync #none',
    # can, depending on the contents of the client workspace, cause
    # much resource usage (and usually in a massive, debilitating way) on
    # the server.
    croak("usage: p4_remove <file>")
	unless defined($file) && length($file);

    p4_cmd("sync $file#none");
}    

sub p4_opened {
    my @lines = p4_cmd("opened @_");
    my @opened;
    for (@lines) {
	next unless m[(//[^#]+)#(\d+) - (\w+)[^()]+ \((\w+)\)(:?$)];
	push @opened, {
	    file	=> $1,
	    revision	=> $2,
	    action	=> $3,
	    type	=> $4,
	}
    }
    return wantarray ? @opened : $opened[0];
}

# Returns a list of integers corresponding the the P4 changes to the entity
# you pass in. If you want to deal with a directory, append '...'.
sub p4_changes {
    my ($file, $max) = @_;
    my $opt_m = defined $max ? "-m$max" : "";
    my @lines = p4_cmd("changes $opt_m $file");
    my @changes;
    for (@lines) {
	next unless /^Change (\d+) on/;
	push @changes, $1;
    }
    wantarray ? @changes : $changes[0];
}

sub p4_describe {
    my ($change, @opts) = @_;
    my $text = p4_cmd("describe @opts $change");
    my @info = split m[^(
	Change\s\Q$change\E.* |
	Affected\sfiles.*     |
	====\s+.+\s+====
    )]mx, $text;
    shift @info unless $info[0]; # seems to be an empty string. Weird.
    my %desc;
    while (@info) {
	my $tag = shift @info;
	my $dat = shift @info;
	if ($tag =~ m[^Change \Q$change\E by (\S+) on (.*)]) {
	    use Time::Local;
	    $desc{changenum} = $change;
	    $desc{user} = $1;
	    $desc{date_p4} = $2;
	    my ($year, $mon, $day, $h, $m, $s) = split /[\/:\s]/, $desc{date_p4};
	    $mon--;
	    $year -= 1900;
	    $desc{date_raw} = timelocal($s, $m, $h, $day, $mon, $year);
	    $desc{date} = localtime($desc{date_raw});
	    $desc{log} = $dat;
	}
	elsif ($tag =~ m[^Affected files]) {
	    for (split /^/m, $dat) {
		my ($fname, $rev, $action) = m[^\.\.\. ([^#]+)#(\d+)\s(\S+)];
		next unless $fname and $rev and $action;
		$desc{files}{$fname} = {
		    revision => $rev,
		    action   => $action,
		};
	    }
	}
	elsif ($tag =~ m[^====]) {
	    my ($file) = $tag =~ m[^==== ([^#]+)];
	    $desc{files}{$file}{diff} = $dat;
	}
    }
    wantarray ? %desc : \%desc;
}

sub get_rev_range {
    my ($file, $since_time) = @_;
    
    my $start_rev = 1;
    my $max_rev = p4_fstat($file)->{'headRev'} || die "couldn't get headRev";
    
    for my $rev ($start_rev..$max_rev) {
        my $rev_fstat = p4_fstat("$file#$rev");
        if ($rev_fstat->{'headTime'} >= $since_time) {
            # print $rev_fstat->{'headTime'}, " ", $since_time, "\n";
            $start_rev = $rev;
            last;
        }
    }
    
    defined($start_rev) 
        or die "couldn't get start rev for $file, $since_time";
    # print "range: $file -- $start_rev, $max_rev\n";
    return ($start_rev, $max_rev);
}

sub p4_info {
    my %info;
    for (split(/^/, p4_cmd("info"))) {
	chomp;
	s/^([^:]+):\s*// || die;
	my $key = lc($1);
	$key =~ s/\s/_/g;
	$info{$key} = $_;
    }
    return \%info;
}

sub p4_submit {
    return 'ActiveState::P4::Submit'->new(@_);
}

package ActiveState::P4::Submit;
#use Data::Dumper;

sub new {
    my $self = shift;
    my $fake = shift if defined $_[0] and $_[0] =~ /^\d+$/;
    my $info = ActiveState::P4::p4_info();
    my $o = bless {
	filehandle => undef,
	initialized => 0,
	submitted => 0,
	pathspecs => \@_,
        subopts => "",
	fake => $fake,
	p4user => $info->{user_name},
	p4client => $info->{client_name},
    }, ref($self) || $self;
}

sub option {
    my ($o, $opts) = @_;
    die "Must call option before object is initialized" if $o->{initialized};
    $o->{subopts} .= $opts;
}

sub DESTROY {
    my $o = shift;
    $o->submit unless $o->{submitted};
}

sub p4user {
    my $o = shift;
    $o->_getset('p4user', @_);
}

sub p4client {
    my $o = shift;
    $o->_getset('p4client', @_);
}

sub fh {
    my $o = shift;
    $o->_init unless $o->{initialized};
    $o->{filehandle}; # refuse to set the filehandle
}

sub print {
    my $o = shift;
    $o->_init unless $o->{initialized};
    CORE::print {$o->fh} @_;
}

sub write {
    my $o = shift;
    $o->_init unless $o->{initialized};
    my $p = CORE::print {$o->fh} $^A;
    $^A = "";
    $p;
}

sub paths {
    my $o = shift;
    $o->_getset('pathspecs', @_);
}

sub submit {
    my $o = shift;
    $o->print(<<END);

Files:
END
    my ($cmd, $file);
    my $usefile = @{$o->{pathspecs}} > 50;
    if ($usefile) {
	my $fh;
	use File::Temp qw(tempfile);
	($fh, $file) = tempfile();
	print {$fh} "$_\n" for @{$o->{pathspecs}};
	close $fh;
	$cmd = "p4 -x $file opened";
    }
    else {
	$cmd = "p4 opened @{$o->{pathspecs}}";
    }
    open (my $OPENED, "$cmd |")
	or die "can't open pipe to '$cmd': $!";
    while (<$OPENED>) {
	next unless s/#\d+ - (\w+) default change .*$/\t# $1/;
	$o->print("\t$_");
    }
    close ($OPENED) or die "error closing '$cmd': $!";
    close ($o->fh) or die "error closing 'p4 submit': $!";
    unlink $file if $usefile;
    $o->_getset('submitted', 1);
}

sub _init {
    my $o = shift;
    return if $o->{initialized};
    my $cmd = $o->{fake} ? "> $ENV{HOME}/cowardly" : "| p4 submit $o->{subopts} -i";
    open ($o->{filehandle}, $cmd)
      or die "can't open pipe to 'p4 submit -i': $!";
    CORE::print {$o->{filehandle}} <<END;
# A Perforce Change Specification.
#
#  Change:      The change number. 'new' on a new changelist.  Read-only.
#  Date:        The date this specification was last modified.  Read-only.
#  Client:      The client on which the changelist was created.  Read-only.
#  User:        The user who created the changelist. Read-only.
#  Status:      Either 'pending' or 'submitted'. Read-only.
#  Description: Comments about the changelist.  Required.
#  Jobs:        What opened jobs are to be closed by this changelist.
#               You may delete jobs from this list.  (New changelists only.)
#  Files:       What opened files from the default changelist are to be added
#               to this changelist.  You may delete files from this list.
#               (New changelists only.)

Change: new

Client: ${\($o->p4client)}

User:   ${\($o->p4user)}

Status: new

Description:
END
    $o->{initialized} = 1;
}

sub _getset {
    my $o = shift;
    my $slot = shift;
    my $val = shift;
    if (defined $val) {
	$o->{$slot} = $val;
	return $o;
    }
    $o->{$slot};
}

1;

__END__

=head1 NAME

ActiveState::P4

=head1 SYNOPSIS

   use ActiveState::P4 qw(:all);

   # Where is the ActivePerl directory?
   my $dir = p4_where('//depot/main/Apps/ActivePerl/src/Core/...');

   p4_edit("$dir/Configure");
   
   # ... edit $dir/Configure
   
   my $handle = p4_submit("$dir/Configure");

   $handle->print(<<END);
   	This descriptions isn't really good enough!
   END

   $handle->submit;	# or, let it happen automatically at end-of-scope.

=head1 DESCRIPTION

ActiveState::P4 exposes the most commonly used Perforce client commands via
similarly-named functions in Perl.

All the functions return the output of the corresponding p4 commands.

=head2 p4_add()

   p4_add(@files_to_add);

Opens a list of files for add. Nothing will happen until they are submitted.

=head2 p4_edit()

   p4_edit(@files_to_edit);

Opens a list of files for edit. Nothing will happen until they are submitted.

=head2 p4_delete()

   p4_delete(@files_to_delete);

Opens a list of files to delete. The files are removed from the client right
away, but they can be reinstated using p4_revert().

=head2 p4_revert()

   p4_revert(@files_to_revert);

Reverts a list of files on the client. Deleted or edited files are sync'd to
the server, and added files are abandoned.

=head2 p4_integrate()

   p4_integrate($from, $to, @opts);

Integrates/branches changes from the source file to the destination file.

=head2 p4_resolve()

   p4_resolve($optsref, @files);

Merge open files.  The first parameter should be a hashref whose keys are
resolve options, e.g. -af -am -as -at -ay -db -dw -f -n -t -v.

=head2 p4_sync()

   p4_sync($file, $file_rev, @opts);

Syncs a file to the repository. If $file_rev is defined, it is passed to
Perforce as the file's revision number. If there are any @opts, they are passed
to C<p4> as usual.

For example,

   p4_sync("//depot/main/Apps/ActivePerl/Makefile", 4, "-f");

is equivalent to the shell command

   p4 sync -f //depot/main/Apps/ActivePerl/Makefile#4

=head2 p4_sync_rev()

   p4_sync_rev($file, $rev, @opts);

Syncs a file to the repository. $rev is a revision range (which includes
Perforce change numbers):

   p4_sync_rev("//depot/main/Apps/ActivePerl/Makefile", 12345);

is equivalent to

   p4 sync //depot/mains/Apps/ActivePerl/Makefile@12345

Note that passing an undefined revision value is equivalent to calling:

  p4_sync($file, undef, @opts);

=head2 p4_remove()

   p4_remove($file);

Removes the file from the client workspace (does not open for delete).

The following equivalence holds:

   p4_remove($file);

is equivalent to

   p4_sync($file, "none");

which, in turn, is equivalent to

   p4 sync $file#none

=head2 p4_refresh()

   p4_refresh(@files_to_refresh)

Refreshes the files in the client workspace. Does not sync to the latest
revision in the repository -- it just refreshes whatever version of the files
were last checked out.

=head2 p4_files()

   p4_files(@files);

Returns a list of named or matching wild card specification.

If the first argument is a hashref, it will be examined for options and 
not passed to p4.  The following keys can be used for options:

=over 4

=item detailed

If true, p4_files() will return a list of hashrefs containing the 
following keys:

=over 

=item name

The depot name of the file.

=item rev

The current revision of the file.

=item type

The current file type of the file.

=item action

The last change action of the file.

=item num

The last change number of the file.

=back

=back

=head2 p4_changes()

   p4_changes($file, $max_changes);

Returns a list of change numbers for the file. A maximum of $max_changes are
returned.

=head2 p4_describe()

   p4_describe($changenum, @opts);

Returns a hashref in scalar context, or a list of key/value pairs in array
context. Here's an example:

   print Dumper p4_describe(30000, "-du");

This example prints out (edited for brevity):

   $VAR1 = {
       'changenum' => 30000,
       'date' => 'Fri Oct 26 17:28:01 2001',
       'date_p4' => '2001/10/26 17:28:01',
       'date_raw' => 100414481,
       'files' => {
	   '//depot/main/Apps/.../Repository/LWP.pm' => {
	       'action' => 'edit',
	       'diff' => '...', # deleted
	       'revision' => 2,
	   },
	   # Other files omitted...
       },
       'log' => '...',
       'user' => 'neilw@neilw-alfalfa',
   };

=head2 p4_exists()

   p4_exists($file);

Returns 1 if the $file exists in the repository, otherwise a 0. Note that a
deleted file still exists -- it's just deleted.

=head2 p4_fstat()

   p4_fstat($file, $rev);

Returns an arrayref of hashrefs, if multiple changes were found; otherwise
returns a single hashref. Here's an example:

   print Dumper p4_fstat("//depot/main/Apps/XPPM/lib/PPM/PPD.pm");

This example prints out:

   $VAR1 = {
             'headTime' => '1011311991',
             'headChange' => '34406',
             'headAction' => 'delete',
             'headRev' => '22',
             'headType' => 'text',
             'depotFile' => '//depot/main/Apps/XPPM/lib/PPM/PPD.pm'
           };

and is equivalent to:

   p4 fstat -s //depot/main/Apps/XPPM/lib/PPM/PPD.pm

=head2 p4_diff()

   p4_diff($file);
   p4_diff($file, $rev);
   p4_diff($file, $rev1, $rev2);

Returns the textual diff between two revisions of the file. If no revision is
specified, returns the difference between the client's version and that on the
server. If a revision is specified, returns the difference between the
client's version at the specified version on the server.

=head2 p4_diff2()

   p4_diff2($file1, $file2, @opts);

Returns the textual diff between the two files. The options may be used to
specify context diff format, for example.

=head2 p4_where()

   p4_where($path, $which, $preserve);

Returns the pathname where the file is located. By default, returns the
location of $path on the client machine, converted to the "normal" format for
the client's machine. By specifying values for $which, you can control what
field to see:

=over 4

=item 1

C<$which=0>

Returns the location of $path in the repository.

Example:

   p4_where('C:\depot\main\support\...', 0);
   # returns //depot/main/support

=item 2

C<$which=1>

Returns the location of $path in the clientspec.

   p4_where('C:\depot\main\support\...', 1);
   # returns //neilw-trowel/depot/main/support

=item 3

C<$which=2>

Returns the location of $path on the client's filesystem. This is the default.

   p4_where('//depot/main/support/...', 2);
   # returns C:\depot\main\support

=back

The C<$preserve> option determines whether to preserve the '\...' or '/...' at
the end of the string returned, if there is any. If $preserve is true, the
string will be returned as received from C<p4>. Otherwise it will be stripped
if found.

=head2 p4_info()

Returns a reference to a hash containing key information about the
current client and some server information.  This is a sample of how
this hash might look like:

   {
      client_address    => "192.168.3.82:45033",
      client_host       => "myhost.example.com",
      client_name       => "myhost",
      client_root       => "/home/gisle",
      current_directory => "/home/gisle/support/modules",
      server_address    => "srvhost.example.com:1667",
      server_date       => "2002/01/21 17:09:22 PST",
      server_license    => "Example Corp. 45 users (support ends 2001/11/27) ",
      server_root       => "/perforce/p4root",
      server_version    => "P4D/LINUX52X86/2001.1/26850 (2001/10/15)",
      user_name         => "gisle",
   }

=head2 p4_submit()

   p4_submit(@paths_to_submit);
   p4_submit($just_kidding, @paths_to_submit);

Returns an C<ActiveState::P4::Submit> object, which has several methods to
gather enough information to check in the files specified.

If the first parameter to p4_submit() matches the regular expression /^\d+$/,
it will be taken as a flag telling whether to I<really> submit. If the
expression is true, the files will not be submitted to Perforce. Instead, the
submit log will be written to $ENV{HOME}/cowardly, and the files will be left
open.

The methods available to call on the object are:

=over 4

=item 1

p4user()

Gets the username of this submission.

=item 2

p4client()

Get the client of this submission.

=item 3

print()

Adds text to the description of the submission. According to Perforce
formatting rules, you should indent every line by at least a <TAB> character.

Example:

   my $hnd = p4_submit('//depot/...');
   $hnd->print(<<END);
        - Fixed a bug
        - Wrote some code
   END

=item 4

write()

Adds text to the description of the submission. Takes no arguments: assumes
you've been using C<formline()> to accumulate text in Perl's accumulator,
C<$^A>. Clears the accumulator after printing the text therein.

Example:

   my $hnd = p4_submit('//depot/...');
   formline("\t\@>>>>>>>>>>>>>>>>>>>>>>>>>>", "Hello!");
   $hnd->write;

=item 5

fh()

Get the filehandle of the underlying pipe to "| p4 submit -i". Useful if you
want to print formatted output to it directly, without using the wrappers.

=item 6

paths()

Gets or sets the pathspecs that will be submitted. If you pass it an arrayref,
it returns the object again; otherwise it returns the current pathspecs as an
arrayref.

Example:

   my $hnd = p4_submit('//depot/...');
   my @paths = @{$hnd->paths};
   @paths = grep { $_ !~ m{//depot/main/Apps/} } @paths;
   $hnd->paths(\@paths);

=item 7

submit()

Submits the pathspecs to Perforce. Dies if there was an error.

Example:

   my $h = p4_submit(@paths);
   $h->print($description);
   eval { $h->submit };
   die "Error: ... $@" if $@;

Note: submit() is called from the DESTROY() method if you don't call it
explicitly. So code like this also works:

   {
       my $h = p4_submit(@paths);
       $h->print("\tThis is a bad change description.\n");
   }

=item 8

option()

Specifies options to use when calling C<p4 submit>.

Example:

  my $h = p4_submit(@paths);
  $h->option("-r");
  $h->print($desc)
  ...

=back
