#!perl -w

use lib "./lib";
use ActiveState::Menu qw(menu);
use Data::Dump qw(dump);

dump(menu(["&Foo", "&h", "---", "Ba&r", "Ba&z", "&Zebra", "&History"]));
dump(menu(["&Foo", "(Ba&r)", "Ba&z", ["E&xit" => sub {exit}]]));

dump(menu(intro  => "*Bold* _Underline_ Normal",
	  menu   => ["&Foo", "(Ba&r)", "Ba&z", "&Rat"],
	  force  => 1,
	  disabled_selectable => 1,
	  prompt => ">",
	 ));
