#!perl -w

use strict;
use FindBin;
use lib (($FindBin::Bin."/lib")=~/^(.*)$/);
use Test::More tests => 3;

my @expected = qw(Apple::Double::Plugin::File);

ok(my $foo = Apple::Double->new());
ok(my @plugins = sort $foo->plugins);
is_deeply(\@plugins, \@expected, "is deeply");

package Apple::Double;

use strict;
use warnings;
use Module::Pluggable;

sub new {
    my $class = shift;
    return bless {}, $class;

}
1;

