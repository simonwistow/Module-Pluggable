#!perl -w

use strict;
use FindBin;
use Test::More tests => 2;

my $inc  = IncTest->new();
my ($ta) = grep { ref($_) eq 'Text::Abbrev'} $inc->plugins;
ok($ta);
is($ta->MPCHECK, "HELLO");

package IncTest;
use Module::Pluggable search_path => "Text", search_dirs => "t/lib", instantiate => 'new';

sub new {
    my $class = shift;
    return bless {}, $class;
}
1;