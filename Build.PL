use strict;
use Module::Build;

my $build = Module::Build
  ->new( module_name => "Module::Pluggable",
         license     => 'perl',
         requires    => {
                          'Test::More'            => 0,
                          'File::Basename'        => 0,
                          'File::Find::Rule'      => 0,
                          'File::Spec::Functions' => 0,
						  'UNIVERSAL::require'    => 0,
                        },
         create_makefile_pl => 'traditional',
       );

$build->create_build_script;

