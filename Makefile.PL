use strict;
use warnings;

use ExtUtils::MakeMaker;
use File::Spec::Functions qw(catfile);

ExtUtils::MakeMaker->VERSION(6.98) if -f '.gitignore';

# VOS and VMS can't handle dodgy plugin names
# and VOS can't even unpack them so we create them on the
# fly and only run the tests if they're present
my %dodgy_files = (
    catfile('OddTest', 'Plugin', '-Dodgy.pm')   => 'OddTest::Plugin::-Dodgy',
    catfile('EditorJunk', 'Plugin', '#Bar.pm#') => 'EditorJunk::Bar',
    catfile('EditorJunk', 'Plugin', '.#Bar.pm') => 'EditorJunk::Bar',
);

my @files;
unless (grep { lc($^O) eq $_ } qw(vms vos)) {
    foreach my $test (keys %dodgy_files) {
        my ($file) = (catfile("t", "lib", $test)=~/^(.*)$/);
        if (open(FH, ">$file")) {
            my $name = $dodgy_files{$test};
            print FH "package $name;\nsub new {}\n1;";
            close(FH);
            push @files, $file;
        }
    }
}

my %WriteMakefileArgs = (
    NAME                => 'Module::Pluggable',
    VERSION_FROM        => 'lib/Module/Pluggable.pm',
    ABSTRACT_FROM       => 'lib/Module/Pluggable.pm',
    AUTHOR              => 'Simon Wistow <simon@thegestalt.org>',
    LICENSE             => 'perl_5',
    MIN_PERL_VERSION    => '5.00503',
    INSTALLDIRS         => ($] >= 5.008009 && $] <= 5.011000 ? 'perl' : 'site'),

    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker'   => '0',
    },
    PREREQ_PM => {
        'if'                    => '0',
        'File::Basename'        => '0',
        'File::Spec'            => '3.00',
        'Exporter'              => '5.57',  # use Exporter 'import'
        'File::Find'            => '0',
        'File::Spec::Functions' => '0',
        'strict'                => '0',
    },
    TEST_REQUIRES => {
        'Test::More'            => '0',
        'Cwd'                   => '0',
        'Data::Dumper'          => '0',
        'File::Copy'            => '0',
        'File::Find'            => '0',
        'File::Path'            => '0',
        'File::Spec::Functions' => '0',
        'File::Temp'            => '0',
        'base'                  => '0',
        'FindBin'               => '0',
        'strict'                => '0',
        'warnings'              => '0',
    },

    META_MERGE => {
        'meta-spec' => { version => 2 },
        dynamic_config => 0,
        resources => {
            repository => {
                url => 'https://github.com/simonwistow/Module-Pluggable.git',
                web => 'https://github.com/simonwistow/Module-Pluggable',
                type => 'git',
            },
            bugtracker => {
                mailto => 'bug-Module-Pluggable@rt.cpan.org',
                web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Module-Pluggable',
            },
        },
        prereqs => {
            runtime => {
                recommends => {
                    'Module::Runtime' => '0.012',
                },
            },
            test => {
                suggests => {
                    'App::Fatpacker' => '0.010000',
                },
            },
        },
        optional_features => {
            module_runtime => {
                description => "Optionally use Module::Runtime for requiring plugins rather than homegrown system",
                prereqs => {
                    runtime => {
                        requires => {
                            'Module::Runtime' => '0.012',
                        }
                    }
                }
            }
        }
    },
);

# degrade gracefully for older EUMM/older perls

if (!eval { ExtUtils::MakeMaker->VERSION('6.6303') }) {
    $WriteMakefileArgs{BUILD_REQUIRES} = $WriteMakefileArgs{TEST_REQUIRES};
    delete $WriteMakefileArgs{TEST_REQUIRES};
}

if (!eval { ExtUtils::MakeMaker->VERSION('6.5501') }) {
    @{$WriteMakefileArgs{PREREQ_PM}}{ keys %{$WriteMakefileArgs{BUILD_REQUIRES}} } =
        @{$WriteMakefileArgs{BUILD_REQUIRES}}{ keys %{$WriteMakefileArgs{BUILD_REQUIRES}} };

    delete $WriteMakefileArgs{BUILD_REQUIRES};
}

WriteMakefile(%WriteMakefileArgs);
