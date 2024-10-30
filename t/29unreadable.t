#!perl -w

use strict;

use Test::More;

BEGIN {
    if ($> == 0) {
      plan skip_all => "Running as root";
    } else {
      plan tests => 6;
    }
}

use FindBin;
#use lib (($FindBin::Bin."/lib")=~/^(.*)$/);
use File::Temp qw/tempdir/;
use File::Path qw(make_path);

# The problem with checking for files that are unreadable
# is that we can't check unreadable files into git
# So we're going to create it on the fly 

# First create a tmp directory and then a directory underneath
my $dir  = tempdir();
my $path = "${dir}/lib/Unreadable";
my $file = "${path}/Foo.pm";
make_path($path, CLEANUP => 1);
# ... now create a file
open(my $fh, ">", $file) || die "Couldn't create temporary file $file: $!";
print $fh "package Unreadable::Foo;\n1;\n";
close($fh);
# ... and set the file permissions on that to unreadable
chmod(0200, $file);
# .. and include the new path
push @INC, "${dir}/lib";

# This should die when it can't read the file
my @a = eval { MyTest->plugins };
ok(defined $@, "Got an error");
is_deeply([@a], []);

# This should not die but also shouldn't be able to require the plugin
my @b = eval { MyTest2->plugins };
ok(!$@ , "Didn't get an error $@");
is_deeply([@b], []);

# Now set it readable
chmod(0600, $file);

# This should not die and should be able to require the plugin
my @c = eval { MyTest->plugins };
ok(!$@ , "Didn't get an error $@");
is_deeply([@c], ["Unreadable::Foo"]);

package MyTest;
use File::Spec::Functions qw(catdir);
use strict;
use Module::Pluggable search_path      => "Unreadable", 
                      require          => 1,
                      on_require_error => sub { die $_[1] };

package MyTest2;
use File::Spec::Functions qw(catdir);
use strict;
use Module::Pluggable search_path      => "Unreadable", 
                      require          => 1,
                      on_require_error => sub { 0 };
1;
