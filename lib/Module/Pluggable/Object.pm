package Module::Pluggable::Object;

use strict;
use File::Find ();
use File::Basename;
use File::Spec::Functions qw(splitdir catdir curdir catfile abs2rel);
use Carp qw(croak carp confess);
use Devel::InnerPackage;
use Scalar::Util qw( blessed );

use if $] > 5.017, 'deprecate';

our $VERSION = '5.3';

BEGIN {
    eval {  require Module::Runtime };
    unless ($@) {
        Module::Runtime->import('require_module');
    } else {
        *require_module = sub {
            my $module = shift;
            my $path   = $module . ".pm";
            $path =~ s{::}{/}g;
            require $path;
        };
    }
}


=head1 NAME

Module::Pluggable::Object - the underlying plugin-finding object used by Module::Pluggable

=head1 SYNOPSIS

    package MyClass;
    use Module::Pluggable::Object;

    my $finder = Module::Pluggable::Object->new(
        package     => __PACKAGE__,
        search_path => ['MyClass::Plugin'],
        require     => 1,
    );

    my @plugins = $finder->plugins;
    print "Found: ", join(", ", @plugins), "\n";

=head1 DESCRIPTION

C<Module::Pluggable::Object> is the engine underneath L<Module::Pluggable>. It
walks a set of search paths (namespaces and directories) looking for C<.pm>
files, maps their paths to package names, and optionally C<require>s or
instantiates them.

Most of the time you should use L<Module::Pluggable> directly, which wraps
this class and exports a C<plugins()> method into your namespace. Use this
class directly when you need more control:

=over 4

=item * You want to create multiple independent finders in the same package.

=item * You want to subclass or decorate the finder object.

=item * You want to store the finder and call C<plugins()> on it explicitly
rather than through an exported method.

=item * You are building your own higher-level abstraction on top of the
plugin-discovery machinery.

=back

=head1 CONSTRUCTOR

=head2 new(%opts)

    my $finder = Module::Pluggable::Object->new(%opts);

Creates and returns a new finder object. All options are passed as a flat
hash; they are stored on the object and consulted by L</plugins>. See
L</OPTIONS> below for the full list.

=cut

sub new {
    my $class = shift;
    my %opts  = @_;

    return bless \%opts, $class;

}

=head1 METHODS

=head2 plugins

    my @plugins = $finder->plugins;        # list of class names
    my @objects = $finder->plugins(@args); # instances when 'instantiate' is set

The main entry point. Walks C<search_path> across C<search_dirs> (and C<@INC>)
and returns either a sorted list of fully-qualified package names or, if
C<instantiate> is set, a list of objects created by calling the named method
on each plugin class.

Arguments passed to C<plugins()> are forwarded to the C<instantiate> method
on each plugin class.

The full search is repeated on every call, which allows plugins installed
after startup to be discovered at run time. If you do not need dynamic
discovery and want to pay the I/O cost only once, memoize the result yourself:

    our @PLUGINS;
    sub plugins { @PLUGINS ||= shift->_finder->plugins }

=cut

### Eugggh, this code smells
### This is what happens when you keep adding patches
### *sigh*

# Normalises the three supported forms of 'search_path' into an ordered
# list of [$namespace, \%per_path_opts] pairs:
#   "Foo::Plugin"                                  -> plain scalar
#   ["Foo::Plugin", "Bar::Plugin"]                 -> plain arrayref
#   { "Foo::Plugin" => { max_depth => 2 }, ... }    -> hashref, sorted for determinism
#   ["Foo::Plugin", { "Bar::Plugin" => { ... } }]   -> mixed arrayref, preserves order
sub _normalise_search_path {
    my ($sp) = @_;
    return () unless defined $sp;
    return ([$sp, {}]) unless ref $sp;
    if (ref($sp) eq 'HASH') {
        return map { [$_, $sp->{$_} || {}] } sort keys %$sp;
    }
    if (ref($sp) eq 'ARRAY') {
        my @out;
        for my $item (@$sp) {
            if (!ref($item)) {
                push @out, [$item, {}];
            } elsif (ref($item) eq 'HASH') {
                push @out, map { [$_, $item->{$_} || {}] } sort keys %$item;
            }
        }
        return @out;
    }
    return ();
}

sub plugins {
    my $self = shift;
    my @args = @_;

    my $pkg = $self->{'package'};

    # Normalise search_path, then apply the default
    my @path_specs = _normalise_search_path($self->{'search_path'});
    @path_specs = ([$pkg . '::Plugin', {}]) unless @path_specs;

    # If any path carries per-path option overrides, dispatch each path through
    # its own sub-finder and merge results in spec order, deduplicating class names.
    if (grep { %{$_->[1]} } @path_specs) {
        my @results;
        for my $spec (@path_specs) {
            my ($path, $per_path) = @$spec;
            my $sub = ref($self)->new(%$self, %$per_path, search_path => [$path]);
            push @results, $sub->plugins(@args);
        }
        my %seen;
        return grep { ref($_) ? 1 : !$seen{$_}++ } @results;
    }

    # No per-path overrides: restore as a simple arrayref and continue as normal
    $self->{'search_path'} = [map { $_->[0] } @path_specs];

    # override 'require'
    $self->{'require'} = 1 if $self->{'inner'};

    my $filename   = $self->{'filename'};

    # Get the exception params instantiated
    $self->_setup_exceptions;

    # automatically turn a scalar search_dirs into an arrayref
    $self->{'search_dirs'} = [ $self->{'search_dirs'} ]
        if exists $self->{'search_dirs'} && !ref($self->{'search_dirs'});

    # default error handler
    $self->{'on_require_error'} ||= sub { my ($plugin, $err) = @_; carp "Couldn't require $plugin : $err"; return 0 };
    $self->{'on_instantiate_error'} ||= sub { my ($plugin, $err) = @_; carp "Couldn't instantiate $plugin: $err"; return 0 };

    # before and after instantiation hooks
    $self->{'before_instantiate'} ||= sub { 1 };
    $self->{'after_instantiate'}  ||= sub { return $_[1] };

    # default whether to follow symlinks
    # because the default behavior is changed in the Perl-CORE module File::Find VERSION >= '1.39',
    # in lower versions of File::Find, 'follow_symlinks' is (independent from the callers setting of
    # 'follow_symlinks') hardcoded set to 0 on Windows so we force File::Find to fall back to the old
    # behavior, if not otherwise told
    $self->{'follow_symlinks'} = 0 if ($File::Find::VERSION >= '1.39' && $^O eq 'MSWin32' && ! exists $self->{'follow_symlinks'} );
    $self->{'follow_symlinks'} = 1 unless exists $self->{'follow_symlinks'};

    # check to see if we're running under test
    my @SEARCHDIR = exists $INC{"blib.pm"} && defined $filename && $filename =~ m!(^|/)blib/! && !$self->{'force_search_all_paths'} ? grep {/blib/} @INC : @INC;

    if ($self->{'search_dirs_strict'}) {
        die "search_dirs_strict: makes no sense without setting search_dirs"
            unless $self->{'search_dirs'};

        @SEARCHDIR = ();
    }

    # add any search_dir params
    unshift @SEARCHDIR, @{$self->{'search_dirs'}} if defined $self->{'search_dirs'};

    # set our @INC up to include and prefer our search_dirs if necessary
    my @tmp = @INC;
    unshift @tmp, @{$self->{'search_dirs'} || []};
    local @INC = @tmp if defined $self->{'search_dirs'};

    my @plugins = $self->search_directories(@SEARCHDIR);
    push(@plugins, $self->handle_inc_hooks($_, @SEARCHDIR)) for @{$self->{'search_path'}};
    push(@plugins, $self->handle_innerpackages($_)) for @{$self->{'search_path'}};

    # return blank unless we've found anything
    return () unless @plugins;

    # remove duplicates, keeping track of discovery order for 'sort_results'
    my (@dedupe, %plugins);
    for(@plugins) {
        next unless $self->_is_legit($_);
        next if $plugins{$_}++;
        push @dedupe, $_;
    }

    my $sort_results = exists $self->{'sort_results'} ? $self->{'sort_results'} : 'alpha';
    my @ordered = $sort_results eq 'path' ? @dedupe
                : !$sort_results          ? keys %plugins
                :                           sort keys %plugins;

    # are we instantiating or requiring?
    if (defined $self->{'instantiate'}) {
        my $method = $self->{'instantiate'};
        my @objs   = ();
        foreach my $package (@ordered) {
            next unless $package->can($method);
            $self->{'before_instantiate'}->($package)
                or next;
            my $obj = eval { $package->$method(@_) }; # We dont actually care what ->$method() returns
            $self->{'on_instantiate_error'}->($package, $@) if $@;
            if ($obj) {
                $obj = $self->{'after_instantiate'}->($package,$obj)
                    or next; # Again, we dont actually care if we get a blessed reference or not
                push @objs, $obj;
            }
        }
        return @objs;
    } else {
        # no? just return the names
        my @objs = @ordered;
        return @objs;
    }
}

sub _setup_exceptions {
    my $self = shift;

    my %only;
    my %except;
    my $only;
    my $except;

    if (defined $self->{'only'}) {
        if (ref($self->{'only'}) eq 'ARRAY') {
            %only   = map { $_ => 1 } @{$self->{'only'}};
        } elsif (ref($self->{'only'}) eq 'Regexp') {
            $only = $self->{'only'}
        } elsif (ref($self->{'only'}) eq '') {
            $only{$self->{'only'}} = 1;
        }
    }


    if (defined $self->{'except'}) {
        if (ref($self->{'except'}) eq 'ARRAY') {
            %except   = map { $_ => 1 } @{$self->{'except'}};
        } elsif (ref($self->{'except'}) eq 'Regexp') {
            $except = $self->{'except'}
        } elsif (ref($self->{'except'}) eq '') {
            $except{$self->{'except'}} = 1;
        }
    }
    $self->{_exceptions}->{only_hash}   = \%only;
    $self->{_exceptions}->{only}        = $only;
    $self->{_exceptions}->{except_hash} = \%except;
    $self->{_exceptions}->{except}      = $except;

}

sub _is_legit {
    my $self   = shift;
    my $plugin = shift;
    my %only   = %{$self->{_exceptions}->{only_hash}||{}};
    my %except = %{$self->{_exceptions}->{except_hash}||{}};
    my $only   = $self->{_exceptions}->{only};
    my $except = $self->{_exceptions}->{except};
    my $depth  = () = split '::', $plugin, -1;

    return 0 if     (keys %only   && !$only{$plugin} );
    return 0 unless (!defined $only || $plugin =~ m!$only! );

    return 0 if     (keys %except &&  $except{$plugin} );
    return 0 if     (defined $except &&  $plugin =~ m!$except! );

    return 0 if     defined $self->{max_depth} && $depth>$self->{max_depth};
    return 0 if     defined $self->{min_depth} && $depth<$self->{min_depth};

    return 0 if     $plugin =~ /(^|::).AppleDouble/;

    return 1;
}

=head2 search_directories(@dirs)

    my @plugins = $finder->search_directories(@INC);

Iterates over C<@dirs> and delegates to L</search_paths> for each one.
Normally called internally by L</plugins>, but exposed so subclasses can
override the top-level directory loop.
=cut

sub search_directories {
    my $self      = shift;
    my @SEARCHDIR = @_;

    my @plugins;
    # go through our @INC
    foreach my $dir (@SEARCHDIR) {
        push @plugins, $self->search_paths($dir);
    }
    return @plugins;
}

=head2 search_paths($dir)

    my @plugins = $finder->search_paths($dir);

For a single base directory, iterates over C</search_path> namespaces, locates
C<.pm> files under the corresponding subdirectory, converts file paths to
package names, and calls L</handle_finding_plugin> for each candidate.

Handles case-insensitive filesystems by reading the C<package> declaration
out of the file when the file name is all-lower or all-upper case.

=cut

sub search_paths {
    my $self = shift;
    my $dir  = shift;
    my @plugins;

    my $file_regex = $self->{'file_regex'} || qr/\.pm$/;


    # and each directory in our search path
    foreach my $searchpath (@{$self->{'search_path'}}) {
        # create the search directory in a cross platform goodness way
        my $sp = catdir($dir, (split /::/, $searchpath));

        # if it doesn't exist or it's not a dir then skip it
        next unless ( -e $sp && -d _ ); # Use the cached stat the second time

        my @files = $self->find_files($sp);

        # foreach one we've found
        foreach my $file (@files) {
            # untaint the file; accept .pm only
            next unless ($file) = ($file =~ /(.*$file_regex)$/);
            # parse the file to get the name
            my ($name, $directory, $suffix) = fileparse($file, $file_regex);

            next if (!$self->{include_editor_junk} && $self->_is_editor_junk($name));

            $directory = abs2rel($directory, $sp);

            # If we have a mixed-case package name, assume case has been preserved
            # correctly.  Otherwise, root through the file to locate the case-preserved
            # version of the package name.
            my @pkg_dirs = ();
            if ( $name eq lc($name) || $name eq uc($name) ) {
                my $pkg_file = catfile($sp, $directory, "$name$suffix");
                open PKGFILE, "<$pkg_file" or die "search_paths: Can't open $pkg_file: $!";
                my $in_pod = 0;
                while ( my $line = <PKGFILE> ) {
                    $in_pod = 1 if $line =~ m/^=\w/;
                    $in_pod = 0 if $line =~ /^=cut/;
                    next if ($in_pod || $line =~ /^=cut/);  # skip pod text
                    next if $line =~ /^\s*#/;               # and comments
                    if ( $line =~ m/^\s*package\s+(.*::)?($name)\s*;/i ) {
                        @pkg_dirs = split /::/, $1 if defined $1;;
                        $name = $2;
                        last;
                    }
                }
                close PKGFILE;
            }

            # then create the class name in a cross platform way
            $directory =~ s/^[a-z]://i if($^O =~ /MSWin32|dos/);       # remove volume
            my @dirs = ();
            if ($directory) {
                ($directory) = ($directory =~ /(.*)/);
                @dirs = grep(length($_), splitdir($directory))
                    unless $directory eq curdir();
                for my $d (reverse @dirs) {
                    my $pkg_dir = pop @pkg_dirs;
                    last unless defined $pkg_dir;
                    $d =~ s/\Q$pkg_dir\E/$pkg_dir/i;  # Correct case
                }
            } else {
                $directory = "";
            }
            my $plugin = join '::', $searchpath, @dirs, $name;

            next unless $plugin =~ m!(?:[a-z\d]+)[a-z\d]*!i;

            $self->handle_finding_plugin($plugin, \@plugins)
        }

        # now add stuff that may have been in package
        # NOTE we should probably use all the stuff we've been given already
        # but then we can't unload it :(
        push @plugins, $self->handle_innerpackages($searchpath);
    } # foreach $searchpath

    return @plugins;
}

sub _is_editor_junk {
    my $self = shift;
    my $name = shift;

    # Emacs (and other Unix-y editors) leave temp files ending in a
    # tilde as a backup.
    return 1 if $name =~ /~$/;
    # Emacs makes these files while a buffer is edited but not yet
    # saved.
    return 1 if $name =~ /^\.#/;
    # Vim can leave these files behind if it crashes.
    return 1 if $name =~ /^[._].*\.s[a-w][a-z]$/;

    return 0;
}

=head2 handle_finding_plugin($plugin, \@plugins, $no_require)

    $finder->handle_finding_plugin('MyApp::Plugin::Foo', \@plugins);

Called for each candidate package name discovered during the search. Applies
the C<only>/C<except>/C<min_depth>/C<max_depth> filters, invokes
C<before_require> and C<after_require> triggers, optionally C<require>s the
module, and pushes it onto C<\@plugins> if everything succeeds.

Pass a true value for C<$no_require> to skip the C<require> step (used when
the module is known to already be loaded, e.g. for inner packages).

=cut

sub handle_finding_plugin {
    my $self    = shift;
    my $plugin  = shift;
    my $plugins = shift;
    my $no_req  = shift || 0;

    return unless $self->_is_legit($plugin);
    unless (defined $self->{'instantiate'} || $self->{'require'}) {
        push @$plugins, $plugin;
        return;
    }

    $self->{before_require}->($plugin) || return if defined $self->{before_require};
    unless ($no_req) {
        my $tmp = $@;
        my $res = eval { require_module($plugin) };
        my $err = $@;
        $@      = $tmp;
        if ($err) {
            if (defined $self->{on_require_error}) {
                $self->{on_require_error}->($plugin, $err) || return;
            } else {
                return;
            }
        }
    }
    $self->{after_require}->($plugin) || return if defined $self->{after_require};
    push @$plugins, $plugin;
}

=head2 find_files($search_path)

    my @files = $finder->find_files($dir);

Recursively finds all files matching C<file_regex> (default C<qr/\.pm$/>) under
C<$dir> using L<File::Find>. Respects the C<follow_symlinks> option.

=cut

sub find_files {
    my $self         = shift;
    my $search_path  = shift;
    my $file_regex   = $self->{'file_regex'} || qr/\.pm$/;


    # find all the .pm files in it
    # this isn't perfect and won't find multiple plugins per file
    #my $cwd = Cwd::getcwd;
    my @files = ();
    { # for the benefit of perl 5.6.1's Find, localize topic
        local $_;
        File::Find::find( { no_chdir => 1,
                            follow   => $self->{'follow_symlinks'},
                            wanted   => sub {
                             # Inlined from File::Find::Rule C< name => '*.pm' >
                             return unless $File::Find::name =~ /$file_regex/;
                             (my $path = $File::Find::name) =~ s#^\\./##;
                             push @files, $path;
                           }
                      }, $search_path );
    }
    #chdir $cwd;
    return @files;

}

=head2 handle_inc_hooks($search_path, @dirs)

    my @plugins = $finder->handle_inc_hooks($path, @SEARCHDIR);

Handles the case where an entry in C<@INC> is a blessed object with a
C<files()> method (as used by L<App::FatPacker> and L<PAR>). Calls
C<files()> on each such object, filters by C<$search_path>, and delegates
to L</handle_finding_plugin>.

=cut

sub handle_inc_hooks {
    my $self      = shift;
    my $path      = shift;
    my @SEARCHDIR = @_;

    my @plugins;
    for my $dir ( @SEARCHDIR ) {
        next unless blessed( $dir ) && $dir->can( 'files' );

        foreach my $plugin ( $dir->files ) {
            $plugin =~ s/\.pm$//;
            $plugin =~ s{/}{::}g;
            next unless $plugin =~ m!^${path}::!;
            $self->handle_finding_plugin( $plugin, \@plugins );
        }
    }
    return @plugins;
}

=head2 handle_innerpackages($search_path)

    my @plugins = $finder->handle_innerpackages('MyApp::Plugin');

Uses L<Devel::InnerPackage> to find any package declared inside an already-
loaded file whose name falls under C<$search_path>. This is how
C<Something::Plugin::Bar> is discovered when it is defined inside
F<Something/Plugin/Foo.pm>. Set C<< inner => 0 >> to disable this behaviour.

=cut

sub handle_innerpackages {
    my $self = shift;
    return () if (exists $self->{inner} && !$self->{inner});

    my $path = shift;
    my @plugins;

    foreach my $plugin (Devel::InnerPackage::list_packages($path)) {
        $self->handle_finding_plugin($plugin, \@plugins, 1);
    }
    return @plugins;

}

1;

=head1 OPTIONS

All options are passed to C<new> as a flat hash and may be set or overridden
directly on the object before calling C<plugins>.

=head2 package

The package name used to build the default C<search_path>. When using
L<Module::Pluggable> this is set automatically to the calling package. When
using C<Module::Pluggable::Object> directly you should set it explicitly.

=head2 search_path

An array ref (or a single string, which is promoted to an array ref) of
namespace prefixes to search. Defaults to C<["${package}::Plugin"]>.

    search_path => ['MyApp::Plugin', 'MyApp::Extension']

Alternatively, you can pass a hash ref where each key is a namespace prefix and
each value is a hash ref of option overrides for that path. The per-path
options are merged on top of the global options, so you only need to
specify what differs.

    search_path => {
        'MyApp::Plugin'    => { max_depth => 2 },
        'MyApp::Extension' => { max_depth => 3, instantiate => 'new' },
    }

As another alternative, if you want plugins to be in a particular order, use
an array ref of mixed plain strings and single-key hash refs. Order is
preserved; only the hash ref entries carry per-path option overrides.

    search_path => [
        'MyApp::Plugin',
        { 'MyApp::Extension' => { max_depth => 3, instantiate => 'new' } },
    ]

Results from all paths are combined and returned in a single list. Class
names are deduplicated across paths; if any path uses C<instantiate> its
objects are included as-is alongside any class names from other paths.

=head2 search_dirs

An array ref (or a single string) of filesystem directories to search
I<before> C<@INC>. Use this when plugins live outside the normal include
path.

    search_dirs => ['/opt/myapp/plugins']

=head2 search_dirs_strict

When true, only the directories in C<search_dirs> are searched; C<@INC> is
ignored entirely. Requires C<search_dirs> to also be set.

    search_dirs_strict => 1

=head2 instantiate

Name of the method to call on each plugin class to create an instance.
Typically C<'new'>. When set, C<plugins()> returns a list of objects instead
of class names. Arguments passed to C<plugins()> are forwarded to this method.

    instantiate => 'new'

=head2 require

When true, each plugin module is C<require>d but not instantiated. Overrides
C<instantiate>. Also enables inner-package discovery (see L</inner>).

    require => 1

=head2 inner

Controls whether inner packages (secondary C<package> declarations inside a
single F<.pm> file) are discovered.

=over 4

=item * Defaults to true when C<require> or C<instantiate> is set.

=item * Set to C<0> to disable even when C<require> is set.

=back

    inner => 0

=head2 only

Restricts the returned plugins to those matching this value. May be:

=over 4

=item * A string - only the exact named plugin is returned.

=item * An array ref of strings - only those exact plugins are returned.

=item * A compiled regex - only plugins whose name matches are returned.

=back

    only => qr/^MyApp::Plugin::Safe/

=head2 except

Excludes matching plugins from the results. Accepts the same forms as C<only>.

    except => ['MyApp::Plugin::Broken', 'MyApp::Plugin::Deprecated']

=head2 min_depth / max_depth

Restrict discovery to plugins at a certain namespace depth (number of
C<::>-separated components).

For example, C<MyApp::Plugin::Foo> has depth 3 and
C<MyApp::Plugin::Foo::Bar> has depth 4.

    max_depth => 3   # only MyApp::Plugin::Foo, not MyApp::Plugin::Foo::Bar
    min_depth => 4   # only MyApp::Plugin::Foo::Bar and deeper

=head2 file_regex

A compiled regex used to identify plugin files. Defaults to C<qr/\.pm$/>.

    file_regex => qr/\.plugin$/

=head2 follow_symlinks

Whether to follow symbolic links when walking the filesystem. Defaults to
C<1> (follow symlinks) on all platforms except Windows with
L<File::Find> E<ge> 1.39, where it defaults to C<0> to preserve the
historical behaviour.

    follow_symlinks => 0

=head2 include_editor_junk

By default, files that look like editor artefacts are silently skipped:

=over 4

=item * Files ending in C<~> (Emacs / generic backup files).

=item * Files beginning with C<.#> (Emacs lock files).

=item * Files matching C<^[._].*\.s[a-w][a-z]$> (Vim swap files).

=back

Set C<include_editor_junk> to a true value to disable this filtering and
include every file that matches C<file_regex>.

    include_editor_junk => 1

=head2 force_search_all_paths

By default, when the module is loaded from inside a C<blib/> tree (i.e.
during C<make test>), only C<@INC> entries that themselves contain C<blib>
are searched. Set this option to search all of C<@INC> regardless.

    force_search_all_paths => 1

=head2 sort_results

Controls the order plugin names (or objects) are returned in. One of:

=over 4

=item * C<'alpha'> (the default) - sorted alphabetically by package name.

=item * C<'path'> - returned in search-path discovery order: all plugins
under the first C<search_path> entry, then the second, and so on. Within a
single path, order follows the underlying filesystem traversal.

=item * C<0> - no sort is applied at all. Fastest option, for callers that
will sort or otherwise order the results themselves.

=back

    sort_results => 'path'

=head1 TRIGGERS

Triggers are callbacks passed as options to C<new>. If a trigger returns
C<0> (or any false value), the plugin is dropped at that point in the
pipeline.

=head2 before_require

    before_require => sub { my ($plugin) = @_; ... }

Called with the plugin package name before it is C<require>d. Return C<0> to
skip both the C<require> and all subsequent steps for this plugin.

=head2 on_require_error

    on_require_error => sub { my ($plugin, $err) = @_; ... }

Called when C<require> raises an exception. The default handler C<carp>s the
error and returns C<0> (dropping the plugin). Return a true value to keep the
plugin in the list despite the error.

=head2 after_require

    after_require => sub { my ($plugin) = @_; ... }

Called after a successful C<require>. Return C<0> to exclude the plugin from
results even though it has already been loaded.

=head2 before_instantiate

    before_instantiate => sub { my ($plugin) = @_; ... }

Called with the plugin package name before the C<instantiate> method is
invoked. Return C<0> to skip instantiation for this plugin.

=head2 on_instantiate_error

    on_instantiate_error => sub { my ($plugin, $err) = @_; ... }

Called when the C<instantiate> method raises an exception. The default handler
C<carp>s the error and returns C<0>.

=head2 after_instantiate

    after_instantiate => sub { my ($plugin, $obj) = @_; return $obj }

Called after successful instantiation with the plugin name and the newly
created object. The return value is used as the plugin entry in the results
list; return a false value to discard the plugin entirely. Use this to wrap
or decorate plugin objects transparently.

=head1 BEHAVIOUR UNDER TEST ENVIRONMENTS

When C<blib.pm> is present in C<%INC> and the calling file's path contains
C<blib/>, only C<@INC> entries that themselves contain C<blib> are searched.
This prevents installed (non-blib) versions of plugins from interfering with
tests. See C<force_search_all_paths> to override this.

=head1 @INC HOOKS AND App::FatPacker

If an entry in C<@INC> is a blessed object with a C<files()> method, its
C<files()> list is searched for plugin modules. This is how L<App::FatPacker>
(from version 0.10.0 onwards) integrates with C<Module::Pluggable::Object>,
and how L<PAR> can be made to do the same. See F<t/26inc_hook.t> for a
working example.

=head1 AUTHOR

Simon Wistow <simon@thegestalt.org>

=head1 COPYING

Copyright, 2006-2026 Simon Wistow

Distributed under the same terms as Perl itself.

=head1 SEE ALSO

L<Module::Pluggable>, L<Devel::InnerPackage>,
L<Module::Runtime>, L<App::FatPacker>, L<PAR>

=cut

