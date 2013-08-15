#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 13;
use File::Spec;

BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Database::Terminfo::Interface', qw/:all/ ) || print "Bail out!\n";
    $ENV{MARPAX_DATABASE_TERMINFO_BIN} = File::Spec->catfile('share', 'ncurses-terminfo.storable');
    $ENV{MARPAX_DATABASE_TERMINFO_CAPS} = File::Spec->catfile('share', 'ncurses-Caps');
}
tgetent('dumb');
my $area;
is(ref(tgetstr('bl')), 'SCALAR', "tgetstr('bl') returns a reference to a scalar");
is(${tgetstr('bl', \$area)}, '^G', "tgetstr('bl') deferenced scalar");
is($area, '^G', "tgetstr('bl', \\\$area) where \\\$area is undef");
is(pos($area), 2, "pos(\\\$area) == 2");
$area = 'x';
pos($area) = length($area);
is(ref(tgetstr('bl')), 'SCALAR', "tgetstr('bl')");
is(${tgetstr('bl', \$area)}, '^G', "tgetstr('bl')");
is($area, 'x^G', "tgetstr('bl', \\\$area) where \\\$area is \"x\" and its pos() is 1");
is(pos($area), 3, "pos(\\\$area) == 3");
$area = 'x';
pos($area) = undef;
is(ref(tgetstr('bl')), 'SCALAR', "tgetstr('bl')");
is(${tgetstr('bl', \$area)}, '^G', "tgetstr('bl')");
is($area, '^Gx', "tgetstr('bl', \\\$area) where \\\$area is \"x\" and its pos() is undef");
is(pos($area), 2, "pos(\\\$area) == 2");
