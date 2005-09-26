#!perl -w

use strict;
use lib 't/lib';
use Test::More tests => 2;


SKIP: {
             skip "Until inner packages have been done properly", 2;

my $t = InnerTest->new();

my %plugins = map { $_ => 1 } $t->plugins;

ok(keys %plugins);
ok($plugins{'InnerTest::Plugin::Foo'});



package InnerTest;
use strict;
use Module::Pluggable;
use base qw(Module::Pluggable);


sub new {
    my $class = shift;
    return bless {}, $class;

}

}

package InnerTest::Plugin::Foo;

1;

