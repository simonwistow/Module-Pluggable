#!perl
# Run by the 'install' target in the generated Makefile (see MY::postamble
# in Makefile.PL). Deletes any copy of this module left behind in a core
# Perl library directory by an old release that used INSTALLDIRS => 'perl'.
# Those directories come before the site directories in @INC, so a stale
# copy there silently shadows the newly installed 'site' copy (#39).
use strict;
use warnings;
use Config;

my @rel_paths = (
    'Module/Pluggable.pm',
    'Module/Pluggable/Object.pm',
);

my @core_dirs = grep { defined && length && -d $_ }
    ($Config{installprivlib}, $Config{installarchlib});

for my $dir (@core_dirs) {
    for my $rel (@rel_paths) {
        my $path = "$dir/$rel";
        next unless -e $path;
        print "Removing stale core copy: $path\n";
        unlink $path or warn "Couldn't remove $path: $!\n";
    }
}
