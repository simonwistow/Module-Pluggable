#!perl -w

use strict;
use lib 't/lib';
use Test::More qw/no_plan/;

my $foo;
ok($foo = MyTest->new());

my @plugins;
my @expected = qw(MyTest::Plugin::Bar MyTest::Plugin::Foo);
ok(@plugins = $foo->foo);
is_deeply(\@plugins, \@expected);



package MyTest;

use strict;
use Module::Pluggable ( sub_name => 'foo');
use base qw(Module::Pluggable);


sub new {
    my $class = shift;
    return bless {}, $class;

}
1;

