#!perl -w

use strict;
use lib 't/lib';
use Test::More qw/no_plan/;


my $foo;
ok($foo = MyTest->new());

my @expected = ();
my @plugins = $foo->plugins;
is_deeply(\@plugins, \@expected);


package MyTest;
use File::Spec::Functions qw(catdir);
use strict;
use Module::Pluggable (search_path => [catdir(qw(No Such Modules))]);
use base qw(Module::Pluggable);


sub new {
    my $class = shift;
    return bless {}, $class;

}
1;

