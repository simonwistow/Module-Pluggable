#!perl -w

use strict;
use FindBin;
use Test::More tests => 1;

eval { require 'Text::BibTex' };
my $bibtex = !$@;

SKIP: {

skip "This test fails when Text::BibTex is installed", 2 if $bibtex; 
    
IncTest->new()->plugins;
is(Text::Abbrev->MPCHECK, "HELLO");

}
package IncTest;
use Module::Pluggable search_path => "Text", search_dirs => "t/lib", require => 1;

sub new {
    my $class = shift;
    return bless {}, $class;
}
1;