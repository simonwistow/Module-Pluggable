package Module::Pluggable;

use strict;
use vars qw($VERSION);
use File::Find::Rule qw/find/;
use File::Basename;
use File::Spec::Functions qw(splitdir catdir);
use Carp qw(croak);


# ObQuote:
# Bob Porter: Looks like you've been missing a lot of work lately. 
# Peter Gibbons: I wouldn't say I've been missing it, Bob! 


$VERSION = '0.7';

=pod

=head1 NAME

Module::Pluggable - automatically give your module the ability to have plugins

=head1 SYNOPSIS


Simple use Module::Pluggable as a base -

    package MyClass;
    use Module::Pluggable;
    use base qw(Module::Pluggable);
    
    
and then later ...

    use MyClass;
    my $mc = MyClass->new();
    # returns the names of all plugins installed under MyClass::Plugins::*
    my @plugins = $mc->plugins(); 

    
Alternatively, if you don't want to use 'plugins' as the method ...
    
    package MyClass;
    use Module::Pluggable (sub_name => 'foo');
    use base qw(Module::Pluggable);


and then later ...

    my @plugins = $mc->foo();


Or if you want to look in another directory

    package MyClass;
    use Module::Pluggable (search_path => ['Acme/MyClass/Plugin', 'MyClass/Extend']);
    use base qw(Module::Pluggable);


Or if you want to instantiate each plugin rather than just return the name

    package MyClass;
    use Module::Pluggable (instantiate => 'new');
    use base qw(Module::Pluggable);

and then

    # whatever is passed to 'plugins' will be passed 
    # to 'new' for each plugin 
    my @plugins = $mc->plugins(@options); 


    

=head1 DESCRIPTION

Provides a simple but, hopefully, extensible way of having 'plugins' for 
your module. Obviously this isn't going to be the be all and end all of
solutions but it works for me.

Essentially all it does is export a method into your namespace that 
looks through a search path for .pm files and turn those into class names. 

Optionally it instantiates those classes for you.


=head1 OPTIONS

You can pass a hash of options when importing this module.

The options can be ...

=head2 sub_name

The name of the subroutine to create in your namespace. 

By default this is 'plugins'

=head2 search_path

An array ref of paths to look in. Whilst attempts
have been made provide cross platform-ness when 
looking for plugins you'll have to take care of the 
search paths yourself. 

See the test files for examples on how to do this.

But something like this should work


    use File::Spec::Functions qw(catdir);
    # search in Some/Path/To/Plugins but in a cross platform way
    use Module::Pluggable (search_path => [catdir(qw(Some Path To Plugins))]);



=head2 instantiate

Call this method on the class. In general this will probably be 'new'
but it can be whatever you want. Whatever arguments are passed to 'plugins' 
will be passed to the method.

The default is 'undef' i.e just return the class name.
	

=head1 FUTURE PLANS

This does everything I need and I can't really think fo any other 
features I want to add. Finding multiple packages in one .pm file
is probably too hard and AFAICS it should 'just work'[tm] with 
PAR.

However suggestions (and patches) are welcome.

=head1 AUTHOR

Simon Wistow <simon@thegestalt.org>

=head1 COPYING

Copyright, 2003 Simon Wistow

Distributed under the same terms as Perl itself.

=head1 BUGS

None known.

=head1 SEE ALSO

L<File::Spec>, L<File::Find::Rule>, L<File::Basename>, L<Class::Factory::Util>

=cut 


sub import {
    my $class   = shift;
    our %opts   = @_;

    # the default name for the method is 'plugins'
    my $sub = $opts{'sub_name'} || 'plugins';

    # have to turn off refs which makes me feel dirty but hey ho
    no strict 'refs';
    # export the subroutine
    *$sub = sub {
        my $self = shift;

        # default search path is '<Module>/<Name>/Plugin'
        # we use catdir to amke it cross platform
        my $packparts = catdir((split /::/, ref $self), 'Plugin');    

        # they have to take care of the corss platform stuff themselves
        $opts{'search_path'} = [$packparts] unless $opts{'search_path'}; 

        # predeclare
        my @plugins;

        # go through our @INC
        foreach my $dir (@INC) {

            # and each directory in our search path
            foreach my $searchpath (@{$opts{'search_path'}}) {
                # create the search directory in a corss platform goodness way
                my $sp = catdir($dir, $searchpath);
                # if it doesn't exist or it's not a dir then skip it
                next unless ( -e $sp && -d $sp );
                
                # find all the .pm files in it
                # this isn't perfect and won't find multiple plugins per file
                my @files = find( name => "*.pm", in => [$sp] );

                # foreach one we've found 
                foreach my $file (@files) {
                    # parse the file to get the name
                    my ($name) = fileparse($file, qr{\.pm});
                    # then create the class name in a cross platform way
                    push @plugins, join "::", splitdir catdir($searchpath,$name);
                }

            }
        }

        # return blank unless we've found anything
        return () unless @plugins;

        # remove duplicates
        # probably not necessary but hey ho
        my %plugins = map { $_ => 1 } @plugins;

        # are we instantiating?
        if (defined $opts{'instantiate'}) {
			my $method = $opts{'instantiate'};
            return map {
                            # use string based eval to force bareword require
                            eval "require $_"; 
                            # and die it we can't do that 
                            croak "Couldn't instantiate $_" if $@;
                            # instantiate with the options passed into the sub
                            $_->$method(@_); 
                        } sort keys %plugins;
        } else { 
            # no? just return the names
            return sort keys %plugins;
        }

    };

};


1;
