#!perl -w

use strict;
use FindBin;
use Test::More tests => 5;

eval { require 'Text::BibTex' };
my $bibtex = !$@;

SKIP: {

skip "This test fails when Text::BibTex is installed", 2 if $bibtex;

my $inc  = IncTest->new();
my ($ta) = grep { ref($_) eq 'Text::Abbrev'} eval { local ($^W) = 0; $inc->plugins };
ok($ta);
is($ta->MPCHECK, "HELLO");

ok($inc->before() > 0,'before_instantiate fired');

my %after = $inc->after();
ok(keys %after > 0, 'after_instantiate fired');

my $norefs = scalar grep { ref($_) } values %after;
my $total = scalar values %after;
ok($total == $norefs, 'after_instantiate has all refs');

};

package IncTest;
our @BEFORE;
our %AFTER;

use Module::Pluggable search_path => "Text",
                      search_dirs => "t/lib",
                      instantiate => 'module_pluggable',
                      before_instantiate => sub { push @BEFORE, $_[0]; return 1 },
                      after_instantiate  => sub { $AFTER{$_[0]} = $_[1]; return $_[1] },
                      on_require_error     => sub { },
                      on_instantiate_error => sub { };

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub before { @BEFORE }
sub after { %AFTER }

1;
