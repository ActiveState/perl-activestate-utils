#!/usr/bin/perl -w

# Manual testing of ActiveState::Browser :-(

use lib "lib";
use ActiveState::Browser;

ActiveState::Browser::open(shift || "http://www.activestate.com");
