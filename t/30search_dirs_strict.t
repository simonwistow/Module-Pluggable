#!perl -w

use strict;
use FindBin;
use Test::More tests => 3;

SKIP: {

my $inc = IncTest->new();

$inc->plugins;

ok($inc->required() > 0,'before_instantiate fired');

# In other words, we only required LocalIncTest::Plugin::Abbrev, not all the
# other random stuff from a standard @INC.
is_deeply(
  [ $inc->required ],
  [ 'LocalIncTest::Plugin::Abbrev' ],
  'we only required the expected library',
);

my ($ta) = $inc->required;
is($ta->MPCHECK, 'HELLO', 'we got our version of LocalIncTest::Plugin::Abbrev');

};

package IncTest;
our %REQUIRED;

use Module::Pluggable search_path => "LocalIncTest::Plugin",
                      search_dirs => "t/lib",
                      search_dirs_strict => 1,
                      require => 1,
                      after_require  => sub { $REQUIRED{$_[0]} = 1 },
                      on_require_error     => sub { };

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub required {
  my @req = sort keys %REQUIRED;
  return @req;
}

1;
