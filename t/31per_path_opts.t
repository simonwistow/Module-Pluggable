#!perl -w

use strict;
use FindBin;
use lib "$FindBin::Bin/lib";
use Test::More tests => 6;
use Module::Pluggable::Object;

# Basic per-path opts: two paths, no overrides
{
    my $finder = Module::Pluggable::Object->new(
        search_path => {
            'MyTest::Plugin'        => {},
            'MyTest::Extend::Plugin' => {},
        },
        search_dirs => ["$FindBin::Bin/lib"],
    );
    my @plugins = $finder->plugins;
    is_deeply(
        \@plugins,
        [qw(MyTest::Extend::Plugin::Bar MyTest::Plugin::Bar MyTest::Plugin::Foo MyTest::Plugin::Quux::Foo)],
        'both paths searched, results merged and sorted',
    );
}

# Per-path max_depth: restrict one path, not the other
{
    my $finder = Module::Pluggable::Object->new(
        search_path => {
            'MyTest::Plugin'        => { max_depth => 3 },
            'MyTest::Extend::Plugin' => {},
        },
        search_dirs => ["$FindBin::Bin/lib"],
    );
    my @plugins = $finder->plugins;
    is_deeply(
        \@plugins,
        [qw(MyTest::Extend::Plugin::Bar MyTest::Plugin::Bar MyTest::Plugin::Foo)],
        'max_depth => 3 on MyTest::Plugin excludes Quux::Foo',
    );
}

# Deduplication: same plugin reachable via two paths
{
    my $finder = Module::Pluggable::Object->new(
        search_path => {
            'MyTest::Plugin' => {},
            'MyTest::Plugin' => {},   # duplicate key, Perl keeps last — same path twice via hash trick won't work
        },
        search_dirs => ["$FindBin::Bin/lib"],
    );
    my @plugins = $finder->plugins;
    my %seen;
    my @dupes = grep { $seen{$_}++ } @plugins;
    is_deeply(\@dupes, [], 'no duplicates when same plugin appears via multiple paths');
}

# Different options per path are isolated (max_depth on one does not bleed into the other)
{
    my $finder = Module::Pluggable::Object->new(
        search_path => {
            'MyTest::Plugin'        => { max_depth => 3 },
            'MyTest::Extend::Plugin' => { max_depth => 3 },
        },
        search_dirs => ["$FindBin::Bin/lib"],
    );
    my @plugins = $finder->plugins;
    is_deeply(
        \@plugins,
        [qw(MyTest::Plugin::Bar MyTest::Plugin::Foo)],
        'max_depth => 3 applied independently to each path',
    );
}

# Mixed arrayref form: order is preserved (path-discovery order), not re-sorted
# alphabetically across paths, and per-path opts still apply.
{
    my $finder = Module::Pluggable::Object->new(
        search_path => [
            { 'MyTest::Plugin'        => { max_depth => 3 } },
            { 'MyTest::Extend::Plugin' => {} },
        ],
        search_dirs => ["$FindBin::Bin/lib"],
    );
    my @plugins = $finder->plugins;
    is_deeply(
        \@plugins,
        [qw(MyTest::Plugin::Bar MyTest::Plugin::Foo MyTest::Extend::Plugin::Bar)],
        'mixed arrayref: MyTest::Plugin found (depth-limited) before MyTest::Extend::Plugin',
    );
}

# Reversing the arrayref order reverses the result order, confirming it tracks
# the spec rather than falling back to alphabetical sort.
{
    my $finder = Module::Pluggable::Object->new(
        search_path => [
            { 'MyTest::Extend::Plugin' => {} },
            { 'MyTest::Plugin'        => { max_depth => 3 } },
        ],
        search_dirs => ["$FindBin::Bin/lib"],
    );
    my @plugins = $finder->plugins;
    is_deeply(
        \@plugins,
        [qw(MyTest::Extend::Plugin::Bar MyTest::Plugin::Bar MyTest::Plugin::Foo)],
        'mixed arrayref: reversing spec order reverses result order',
    );
}
