#!perl -w

use strict;
use FindBin;
use lib (($FindBin::Bin."/lib")=~/^(.*)$/);
use Test::More tests => 5;

my $foo;
ok($foo = M->new());

my @plugins;
my @expected = qw(M::X);
ok(@plugins = sort $foo->plugins);



is_deeply(\@plugins, \@expected, "is deeply");

@plugins = ();

ok(@plugins = sort M->plugins);




is_deeply(\@plugins, \@expected, "is deeply class");



package M;

use strict;
use Module::Pluggable search_path => "M";


sub new {
    my $class = shift;
    return bless {}, $class;

}
1;

