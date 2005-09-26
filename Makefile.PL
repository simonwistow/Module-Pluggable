
    unless (eval "use Module::Build::Compat 0.02; 1" ) {
      print "This module requires Module::Build to install itself.\n";
      
      require ExtUtils::MakeMaker;
      my $yn = ExtUtils::MakeMaker::prompt
	('  Install Module::Build now from CPAN?', 'y');
      
      unless ($yn =~ /^y/i) {
	warn " *** Cannot install without Module::Build.  Exiting ...\n";
	exit 1;
      }

      require Cwd;
      require File::Spec;
      require CPAN;
      
      # Save this 'cause CPAN will chdir all over the place.
      my $cwd = Cwd::cwd();
      my $makefile = File::Spec->rel2abs($0);
      
      CPAN::Shell->install('Module::Build::Compat');
      
      chdir $cwd or die "Cannot chdir() back to $cwd: $!";
      exec $^X, $makefile, @ARGV;  # Redo now that we have Module::Build
    }
    Module::Build::Compat->run_build_pl(args => \@ARGV);
    Module::Build::Compat->write_makefile();
