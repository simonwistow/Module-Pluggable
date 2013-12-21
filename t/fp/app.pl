#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

my @plugins = App::TestMPFP->plugins();
is_deeply([@plugins], ['App::TestMPFP::Plugin::A'], 'found expected plugins');

package App::TestMPFP;
use Module::Pluggable require => 1;

1;
