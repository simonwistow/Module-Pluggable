#!perl -w

use strict;
use Test::More tests => 2;

my @plugins = Foo->plugins;

is($plugins[0], 'IncHook::Test', "found module");
is($plugins[0]->found_it, 'IncHook::Test', "ran module");


package IncHook;
use strict;

sub new { return bless {}, shift }

sub IncHook::INC {
    my ($self, $filename) = @_;
    return unless $filename eq 'IncHook/Test.pm';
    
    my @sub = ('package IncHook::Test; sub found_it { return __PACKAGE__ }; 1;');
    return sub { defined($_ = shift @sub) };
}

sub files { qw(IncHook/Test.pm) }

package Foo;
use strict;
use Module::Pluggable require => 1, search_path => 'IncHook';

BEGIN { unshift @INC, IncHook->new };
1;