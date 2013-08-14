#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 3;
use File::Spec;

BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Database::Terminfo::Interface', qw/:all/ ) || print "Bail out!\n";
    $ENV{MARPAX_DATABASE_TERMINFO_BIN} = File::Spec->catfile('share', 'ncurses-terminfo.storable');
    $ENV{MARPAX_DATABASE_TERMINFO_CAPS} = File::Spec->catfile('share', 'ncurses-Caps');
}
tgetent('dumb');
my $area;
is(tgetstr('bl', \$area), '^G', "tgetstr('bl')");
is($area, '^G', "tgetstr('bl', \\\$area)");
