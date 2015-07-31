use strict;
use ExtUtils::MakeMaker;
use FindBin;
use File::Spec::Functions qw(catfile);

# VOS and VMS can't handle dodgy plugin names
# and VOS can't even unpack them so we create them on the
# fly and only run the tests if they're present
my %dodgy_files = (
    catfile(qw(OddTest Plugin -Dodgy.pm))   => 'OddTest::Plugin::-Dodgy',
    catfile(qw(EditorJunk Plugin #Bar.pm#)) => 'EditorJunk::Bar',
    catfile(qw(EditorJunk Plugin .#Bar.pm)) => 'EditorJunk::Bar',
);

my $core = grep { $_ eq 'PERL_CORE=1' } @ARGV;
my @path = $core ? (File::Spec->updir, File::Spec->updir, File::Spec->updir,
                   "t", "Module_Pluggable") : ($FindBin::Bin,"t");

my @files;
unless (grep { lc($^O) eq $_ } qw(vms vos)) {
    foreach my $test (keys %dodgy_files) {
        my ($file) = (catfile(@path, "lib", $test)=~/^(.*)$/);
        if (open(FH, ">$file")) {
            my $name = $dodgy_files{$test};
            print FH "package $name;\nsub new {}\n1;";
            close(FH);
            push @files, $file;
        }
    }
}

WriteMakefile(
    NAME => "Module::Pluggable",
    VERSION_FROM => 'lib/Module/Pluggable.pm',
    LICENSE => 'perl',
    PREREQ_PM    => {
        'if'              => '0',
        'File::Basename'  => '0',
        'File::Spec'      => '3.00',
        'Exporter'        => '5.57',  # use Exporter 'import'
    },
    BUILD_REQUIRES => {
        'Test::More'      => '0.62',
    },
    TEST_REQUIRES => {
        'App::FatPacker'  >= '0.10.0',
    },
    clean => { FILES => @files },
    META_MERGE     => {
        resources => {
            repository  => {
                type => 'git',
                url => 'git://github.com/simonwistow/Module-Pluggable',
                web => 'https://github.com/simonwistow/Module-Pluggable',
            },
        },
    },
);
