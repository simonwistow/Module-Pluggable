#!perl -wT

use Test::More tests => 1;
use lib 't/lib';

use Devel::InnerPackage qw(list_packages);
use No::Middle;

my @p = list_packages("No::Middle");
is_deeply([ sort @p ], [ qw(No::Middle::Package::A No::Middle::Package::B) ]);
