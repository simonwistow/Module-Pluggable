#!perl

use strict;
use warnings;

use Test::More;

BEGIN {
    my $need_version = "0.10.0";
    eval "use App::FatPacker $need_version ; 1; "
      or plan skip_all => "App::FatPacker >= $need_version not available";
}

use Cwd 'cwd';
use File::Temp;
use File::Copy;
use File::Find;
use File::Path 'mkpath';  # use legacy interface for backwards compatibility
use File::Spec::Functions qw(catdir catfile splitdir);

# prepare directory for App::FatPacker

my $testdir = File::Temp->newdir;
my $fatlib = catdir($testdir->dirname, 'fatlib');

# copy our Module::Pluggable to $tempdir/fatlib
mkpath $fatlib;
copy_dir('lib', $fatlib, 1);

# Copy the test application and its plugins to $tempdir/lib
copy_dir(catdir('t', 'fp'), $testdir->dirname, 2);

# fatpack it. fatpacker requires files be in the current directory
my $cwd = cwd;
my $packed = eval {
    chdir $testdir or die "unable to chdir to $testdir\n";
    my $fp = App::FatPacker->new;
    $fp->fatpack_file('app.pl');
};
my $err = $@;
chdir $cwd;

BAIL_OUT("error fatpacking test application: $err") if $@;

# write packed application to a file outside of the test dir to
# make sure there's no way it can see its modules
my $packed_file = File::Temp->new;
$packed_file->print($packed);
$packed_file->close;

# run it (and it's included tests )
require_ok $packed_file;

done_testing;

sub copy_dir {
    my ($from, $to, $shift) = @_;

    find(
        sub {
            my @p = splitdir($File::Find::dir);
            splice(@p, 0, $shift);
            my $ddir = catdir($to, @p);

            if (-d $_) {
                $ddir = catdir($ddir, $_);
                mkpath $ddir unless -d $ddir;
            } else {
                unless (copy($_, $ddir)) {
                    my $file = catfile( $File::Find::dir, $_ );
                    die "error copying $file to $ddir: $!\n";
                }
            }
        },
        $from
    );
}
