use strict;
use Module::Build;
use FindBin;

# VOS and VMS can't handle dodgy plugin names
# and VOS can't even unpack them so we create them on the
# fly and only run the tests if they're present
if ($^O ne 'VMS' && $^O ne 'VOS') {
	my ($file) = (($FindBin::Bin."/t/lib/OddTest/Plugin/-Dodgy.pm")=~/^(.*)$/);
	if (open(my $fh, ">", $file)) {
		print $fh "package OddFiles::Plugin::Dodgy;\nsub new {}\n1;";
		close($fh);
	} 
}



my $build = Module::Build
  ->new( module_name => "Module::Pluggable",
         license     => 'perl',
         requires    => {
                          'Test::More'            => '0.62',
                          'File::Basename'        => 0,
                          'File::Spec'            => '3.00',
                        },
         create_makefile_pl => 'traditional',
       );

$build->create_build_script;

