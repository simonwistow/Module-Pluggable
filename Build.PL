use strict;
use Module::Build;
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

my $build = Module::Build
  ->new( module_name => "Module::Pluggable",
         license     => 'perl',
         requires    => {
             'if'              => '0',
             'File::Basename'  => '0',
             'File::Spec'      => '3.00',
         },
         configure_requires => {
              'Module::Build'  => '0.38', 
         },
         build_requires => {
             'Test::More'      => '0.62',
         },
         create_makefile_pl    => 'small',
         installdirs           => ((($] >= 5.008009) && ($] < 5.011)) ? 'core' : 'site'),
       );

$build->add_to_cleanup(@files);
$build->build_elements([grep { $_ ne 'pod' } @{$build->build_elements}]) if $core;
$build->create_build_script;

