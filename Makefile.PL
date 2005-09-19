require v5.6;
use ExtUtils::MakeMaker;

my $DIR = [];
unless ($^O eq "MSWin32") {
    push @$DIR, "File-Atomic";
}

WriteMakefile(
    NAME	 => 'ActiveState::Utils',
    VERSION	 => '1.23',
    DIR		 => $DIR,
    PREREQ_PM    => { 'Time::HiRes' => 1 },
    ($] ge '5.006' ? (
	AUTHOR	 => 'ActiveState Corporation',
	ABSTRACT => 'Internal ActiveState utility modules',
    ) : ()),
);

sub MY::libscan {
    my($self, $path) =@_;
    return '' if $path =~ /\.pl$/;
    return '' if $path =~ /X11TestServer|UTF8/;
    return '' if $^O eq "MSWin32" && $path =~ /Unix/;
    return '' if $path =~ /(P4|X11TestServer|Install).pm$/;
    return $path;
}
