use strict;
use Module::Build;

my $build = Module::Build
  ->new( module_name => "Module::Pluggable",
         license     => 'perl',
         requires    => {
                          'Test::More'            => '0.62',
                          'File::Basename'        => 0,
                          'File::Spec' => '3.00',
                        },
         create_makefile_pl => 'traditional',
       );

$build->create_build_script;

