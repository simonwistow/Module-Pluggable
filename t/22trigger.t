#!perl -w

use strict;
use FindBin;
use lib (($FindBin::Bin."/lib")=~/^(.*)$/);
use Test::More tests => 7;

my $foo;
my @plugins;
my @errors;
ok($foo = TriggerTest->new(), "Created new TriggerTest");
ok(@plugins = $foo->plugins,  "Ran plugins");
ok(@errors  = $foo->errors,   "Got errors");
is_deeply([sort @plugins], ['TriggerTest::Plugin::After', 'TriggerTest::Plugin::CallbackAllow'], "Got the correct plugins");
is_deeply([@errors], ['TriggerTest::Plugin::Error'], "Got the correct errors");
ok(keys %{TriggerTest::Plugin::CallbackDeny::}, "CallbackDeny has been required");
ok(!keys %{TriggerTest::Plugin::Deny::}, "Deny has not been required");

package TriggerTest;

our @ERRORS;
use strict;
use Module::Pluggable require        => 1,
                      on_error       => sub { my $p = shift; push @ERRORS, $p; return 0 },
                      before_require => sub { my $p = shift; return !($p eq "TriggerTest::Plugin::Deny") },
                      after_require  => sub { my $p = shift; return !($p->can('exclude') && $p->exclude) };

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub errors {
    @ERRORS;
}
1;

