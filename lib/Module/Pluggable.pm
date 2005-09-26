package Module::Pluggable;

use strict;
use vars qw($VERSION);
use Cwd        ();
use File::Find ();
use File::Basename;
use File::Spec::Functions qw(splitdir catdir abs2rel);
use Carp qw(croak carp);


# ObQuote:
# Bob Porter: Looks like you've been missing a lot of work lately. 
# Peter Gibbons: I wouldn't say I've been missing it, Bob! 


$VERSION = '2.4';

=pod

=head1 NAME

Module::Pluggable - automatically give your module the ability to have plugins

=head1 SYNOPSIS


Simple use Module::Pluggable -

    package MyClass;
    use Module::Pluggable;
    

and then later ...

    use MyClass;
    my $mc = MyClass->new();
    # returns the names of all plugins installed under MyClass::Plugin::*
    my @plugins = $mc->plugins(); 

=head1 DESCRIPTION

Provides a simple but, hopefully, extensible way of having 'plugins' for 
your module. Obviously this isn't going to be the be all and end all of
solutions but it works for me.

Essentially all it does is export a method into your namespace that 
looks through a search path for .pm files and turn those into class names. 

Optionally it instantiates those classes for you.

=head1 ADVANCED USAGE

    
Alternatively, if you don't want to use 'plugins' as the method ...
    
    package MyClass;
    use Module::Pluggable sub_name => 'foo';


and then later ...

    my @plugins = $mc->foo();


Or if you want to look in another namespace

    package MyClass;
    use Module::Pluggable search_path => ['Acme::MyClass::Plugin', 'MyClass::Extend'];

or directory 

    use Module::Pluggable search_dirs => ['mylibs/Foo'];


Or if you want to instantiate each plugin rather than just return the name

    package MyClass;
    use Module::Pluggable instantiate => 'new';

and then

    # whatever is passed to 'plugins' will be passed 
    # to 'new' for each plugin 
    my @plugins = $mc->plugins(@options); 


alternatively you can just require the module without instantiating it

    package MyClass;
    use Module::Pluggable require => 1;

since requiring automatically searches inner packages, which may not be desirable, you can turn this off


    package MyClass;
    use Module::Pluggable require => 1, inner => 0;


You can limit the plugins loaded using the except option, either as a string,
array ref or regex

    package MyClass;
    use Module::Pluggable except => 'MyClass::Plugin::Foo';

or

    package MyClass;
    use Module::Pluggable except => ['MyClass::Plugin::Foo', 'MyClass::Plugin::Bar'];

or

    package MyClass;
    use Module::Pluggable except => qr/^MyClass::Plugin::(Foo|Bar)$/;


and similarly for only which will only load plugins which match.

Remember you can use the module more than once

	package MyClass;
	use Module::Pluggable search_path => 'MyClass::Filters' sub_name => 'filters';
	use Module::Pluggable search_path => 'MyClass::Plugins' sub_name => 'plugins';

and then later ...

	my @filters = $self->filters;
	my @plugins = $self->plugins;

=head1 INNER PACKAGES

If you have, for example, a file B<lib/Something/Plugin/Foo.pm> that
contains package definitions for both C<Something::Plugin::Foo> and 
C<Something::Plugin::Bar> then as long as you either have either 
the B<require> or B<instantiate> option set then we'll also find 
C<Something::Plugin::Bar>. Nifty!

=head1 OPTIONS

You can pass a hash of options when importing this module.

The options can be ...

=head2 sub_name

The name of the subroutine to create in your namespace. 

By default this is 'plugins'

=head2 search_path

An array ref of namespaces to look in. 

=head2 search_dirs 

An array ref of directorys to look in before @INC.

=head2 instantiate

Call this method on the class. In general this will probably be 'new'
but it can be whatever you want. Whatever arguments are passed to 'plugins' 
will be passed to the method.

The default is 'undef' i.e just return the class name.

=head2 require

Just require the class, don't instantiate (overrides 'instantiate');

=head2 inner

If set to 0 will B<not> search inner packages. 
If set to 1 will override C<require>.

=head2 only

Takes a string, array ref or regex describing the names of the only plugins to 
return. Whilst this may seem perverse ... well, it is. But it also 
makes sense. Trust me.

=head2 except

Similar to C<only> it takes a description of plugins to exclude 
from returning. This is slightly less perverse.

=head2 package

This is for use by extension modules which build on C<Module::Pluggable>:
passing a C<package> option allows you to place the plugin method in a
different package other than your own.

=head1 FUTURE PLANS

This does everything I need and I can't really think of any other 
features I want to add. Famous last words of course

Recently tried fixed to find inner packages and to make it 
'just work' with PAR but there are still some issues.


However suggestions (and patches) are welcome.

=head1 AUTHOR

Simon Wistow <simon@thegestalt.org>

=head1 COPYING

Copyright, 2003 Simon Wistow

Distributed under the same terms as Perl itself.

=head1 BUGS

None known.

=head1 SEE ALSO

L<File::Spec>, L<File::Find>, L<File::Basename>, L<Class::Factory::Util>, L<Module::Pluggable::Ordered>

=cut 


sub import {
    my $class   = shift;
    my %opts    = @_;

    # override 'require'
    $opts{'require'} = 1 if $opts{'inner'};


    # automatically turn a scalr search path or namespace into a arrayref
    for (qw(search_path search_dirs)) {
        $opts{$_} = [ $opts{$_} ] if exists $opts{$_} && !ref($opts{$_});
    }


    # the default name for the method is 'plugins'
    my $sub = $opts{'sub_name'} || 'plugins';
  

    # get our package 
    my ($pkg) = $opts{'package'} || caller;

    # have to turn off refs which makes me feel dirty but hey ho
    no strict 'refs';
    # export the subroutine
    *{"$pkg\::$sub"} = sub {
        my $self = shift;


        # default search path is '<Module>::<Name>::Plugin'
        $opts{'search_path'} = ["${pkg}::Plugin"] unless $opts{'search_path'}; 

        # predeclare
        my @plugins;

        # check to see if we're running under test
        my @SEARCHDIR = exists $INC{"blib.pm"} ? grep {/blib/} @INC : @INC;

        # add any search_dir params
        unshift @SEARCHDIR, @{$opts{'search_dirs'}} if defined $opts{'search_dirs'};


        # go through our @INC
        foreach my $dir (@SEARCHDIR) {

            # and each directory in our search path
            foreach my $searchpath (@{$opts{'search_path'}}) {
                # create the search directory in a cross platform goodness way
                my $sp = catdir($dir, (split /::/, $searchpath));
                # if it doesn't exist or it's not a dir then skip it
                next unless ( -e $sp && -d _ ); # Use the cached stat the second time


                # find all the .pm files in it
                # this isn't perfect and won't find multiple plugins per file
                my $cwd = Cwd::getcwd;
                my @files = ();
                File::Find::find(
                    sub { # Inlined from File::Find::Rule C< name => '*.pm' >
                        return unless $File::Find::name =~ /\.pm$/;
                        (my $path = $File::Find::name) =~ s#^\\./##;
                        push @files, $path;
                    },
                    $sp );
                chdir $cwd;

                # foreach one we've found 
                foreach my $file (@files) {
                    next unless $file =~ m!\.pm$!;
                    # parse the file to get the name
                    my ($name, $directory) = fileparse($file, qr{\.pm});
                    $directory = abs2rel($directory, $sp);
                    # then create the class name in a cross platform way
                    push @plugins, join "::", splitdir catdir($searchpath, $directory, $name);
                }

            }
        }

        # This code should allow us to have plugins which are inner packages
        # some inner packages can only be found if we use other stuff first
        if (defined $opts{'instantiate'} || $opts{'require'}) {
            for (@plugins) {
                eval "CORE::require $_";
                carp "Couldn't require $_ : $@" if $@;
            }
        }


        # now add stuff that may have been in package
        # NOTE we should probably use all the stuff we've been given already
        # but then we can't unload it :(
        unless (exists $opts{inner} && !$opts{inner}) {
            for my $path (@{$opts{'search_path'}}) {
                for (list_packages($path)) {
                    if (defined $opts{'instantiate'} || $opts{'require'}) {
                        eval "CORE::require $_";
                        # *No warnings here* 
                    }    
                    push @plugins, $_;
                }
            }
        }

        # push @plugins, map { print STDERR "$_\n"; $_->require } list_packages($_) for (@{$opts{'search_path'}});
        
        # return blank unless we've found anything
        return () unless @plugins;

    	# exceptions
    	my %only;   
    	my %except; 
		my $only;
		my $except;

		if (defined $opts{'only'}) {
			if (ref($opts{'only'}) eq 'ARRAY') {
				%only   = map { $_ => 1 } @{$opts{'only'}};
			} elsif (ref($opts{'only'}) eq 'Regexp') {
				$only = $opts{'only'}
			} elsif (ref($opts{'only'}) eq '') {
				$only{$opts{'only'}} = 1;
			}
		}
		

		if (defined $opts{'except'}) {
			if (ref($opts{'except'}) eq 'ARRAY') {
				%except   = map { $_ => 1 } @{$opts{'except'}};
			} elsif (ref($opts{'except'}) eq 'Regexp') {
				$except = $opts{'except'}
			} elsif (ref($opts{'except'}) eq '') {
				$except{$opts{'except'}} = 1;
			}
		}





        # remove duplicates
        # probably not necessary but hey ho
        my %plugins;
        for(@plugins) {
            next if (keys %only   && !$only{$_}     );
			next unless (!defined $only || m!$only! );

            next if (keys %except &&  $except{$_}   );
            next if (defined $except &&  m!$except! );

            $plugins{$_} = 1;
        }

        # are we instantiating or requring?
        if (defined $opts{'instantiate'} || $opts{'require'}) {
            my $method = $opts{'instantiate'};
            return map {
                            #$_->require or carp "Couldn't require $_ : $UNIVERSAL::require::ERROR";
                            # instantiate with the options passed into the sub
                            # unless just requiring
                            $opts{require} ? $_ : $_->$method(@_);
                        } keys %plugins;
        } else { 
            # no? just return the names
            return keys %plugins;
        }

    };

};


sub list_packages {
            my $pack = shift; $pack .= "::" unless $pack =~ m!::$!;

            no strict 'refs';
            my @packs;
            for (grep !/^main::$/, grep /::$/, keys %{$pack})
            {
                s!::$!!;
                my @children = list_packages($pack.$_);
                 push @packs, "$pack$_" unless @children or /^::/; 
                push @packs, @children;
            }
            return @packs;
}


1;
