#!perl -w

use strict;
use lib 't/lib';
use Test::More tests => 4;

my $foo;
ok($foo = MyTest->new());



my @plugins;
ok(@plugins = sort $foo->booga(nork => 'fark'));
is(ref $plugins[0],'MyTest::Extend::Plugin::Bar');
is($plugins[0]->nork,'fark');




package MyTest;
use File::Spec::Functions qw(catdir);
use strict;
use lib 't/lib';
use Module::Pluggable (search_path => ["MyTest::Extend::Plugin"], sub_name => 'booga', instantiate => 'new');


sub new {
    my $class = shift;
    return bless {}, $class;

}
1;

