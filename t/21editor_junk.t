#!perl -w

use Test::More tests => 4;
use FindBin;
use lib "$FindBin::Bin/lib";
use Module::Pluggable::Object;

my $foo;
ok($foo = EditorJunk->new());

my @plugins;
my @expected = qw(EditorJunk::Plugin::Bar EditorJunk::Plugin::Foo);
ok(@plugins = sort $foo->plugins);

is_deeply(\@plugins, \@expected, "is deeply");


my $mpo = Module::Pluggable::Object->new(
    package             => 'EditorJunk',
    filename            => __FILE__,
    include_editor_junk => 1,
);

@expected = ('EditorJunk::Plugin::.#Bar', 'EditorJunk::Plugin::Bar', 'EditorJunk::Plugin::Foo');
@plugins = sort $mpo->plugins();
is_deeply(\@plugins, \@expected, "is deeply");



package EditorJunk;

use strict;
use Module::Pluggable;


sub new {
    my $class = shift;
    return bless {}, $class;

}
1;


