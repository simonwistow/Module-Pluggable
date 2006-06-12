#!perl -wT

use Test::More tests => 1;

use Devel::InnerPackage qw(list_packages);
use lib qw(t/lib);

my @packages;

use_ok("No::Middle");
ok(@packages = list_packages("No::Middle"));
is_deeply([sort @packages], [qw(No::Middle::Package::A No::Middle::Package::B)]);

