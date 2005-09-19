#!perl -w
use Test;

my $glxinfo = '/usr/X11R6/bin/glxinfo';
unless (-x $glxinfo) {
  print "1..0 # skip: needs glxinfo\n";
  exit;
}

unless (gethostbyname("plow.activestate.com")) {
  print "1..0 # skip: Must be able to access plow\n";
  exit;
}

plan tests => 13;

use strict;
use ActiveState::X11TestServer;

ok 1;

#Remote test
{
my $x11; 
eval { 
  $x11 = ActiveState::X11TestServer->new(
    order => [qw(remote)],
  );
};
ok !$@;
ok $x11;
ok $x11 && $x11->display;
ok glx_ok($x11);
}

#Local test
{
my $x11;
eval { 
  $x11 = ActiveState::X11TestServer->new(
    order => [qw(local)],
  );
};
my $no_local;
if ($@ =~ /find a way to provide a X server/) {
  $no_local = "No local X11 Server binary";
}

skip ($no_local, !$@);
skip ($no_local, $x11);
skip ($no_local, $x11 && $x11->display);
skip ($no_local, glx_ok($x11));
}

#Managed test
{
my $x11;
eval { 
  $x11 = ActiveState::X11TestServer->new(
    order => [qw(managed)],
  );
};
ok !$@;
ok $x11;
ok $x11 && $x11->display;
ok glx_ok($x11); 
}              

sub glx_ok {
 my $x = shift;
 return unless $x;
 my $display = $x->display;
 return unless $display;
 local $ENV{DISPLAY} = $display;
 print STDERR "# Display = '$display'\n";
 open(my $info, "$glxinfo -b |") || die "glxinfo failure: $!";
 my $pass = 0;
 while(<$info>) {
   $pass ++ if /^\d+$/;
 }
 close($info);
 return $pass;
}
