#!perl-wT

use strict;
use lib 't/lib';
use Test::More 'no_plan';

use Module::Pluggable search_path => 'Acme::MyTest';

my $topic = "topic";

for ($topic) {
  main->plugins;
}

is($topic, 'topic', "we've got the right topic");
