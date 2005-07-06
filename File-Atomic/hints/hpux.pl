
# need to make sure that only the XS boot function is exported to avoid
# symbol issues wiht the HP loader.
$self->{dynamic_lib} = { 
    OTHERLDFLAGS => '+e boot_ActiveState__File__Atomic'
} if $Config{ld} eq "ld";

$self->{dynamic_lib} = {
    OTHERLDFLAGS => '-Bextern=boot_ActiveState__File__Atomic'
} if $Config{ld} eq "cc";

