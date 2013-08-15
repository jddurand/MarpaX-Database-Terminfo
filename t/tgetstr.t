#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 13;
use File::Spec;

BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Database::Terminfo::Interface', qw/:functions/ ) || print "Bail out!\n";
    $ENV{MARPAX_DATABASE_TERMINFO_BIN} = File::Spec->catfile('share', 'ncurses-terminfo.storable');
    $ENV{MARPAX_DATABASE_TERMINFO_CAPS} = File::Spec->catfile('share', 'ncurses-Caps');
}
my $t = MarpaX::Database::Terminfo::Interface->new();
$t->tgetent('dumb');
my $area;
is(ref($t->tgetstr('bl')), 'SCALAR', "\$t->tgetstr('bl') returns a reference to a scalar");
is(${$t->tgetstr('bl', \$area)}, '^G', "\$t->tgetstr('bl') deferenced scalar");
is($area, '^G', "\$t->tgetstr('bl', \\\$area) where \\\$area is undef");
is(pos($area), 2, "pos(\\\$area) == 2");
$area = 'x';
pos($area) = length($area);
is(ref($t->tgetstr('bl')), 'SCALAR', "\$t->tgetstr('bl')");
is(${$t->tgetstr('bl', \$area)}, '^G', "\$t->tgetstr('bl')");
is($area, 'x^G', "\$t->tgetstr('bl', \\\$area) where \\\$area is \"x\" and its pos() is 1");
is(pos($area), 3, "pos(\\\$area) == 3");
$area = 'x';
pos($area) = undef;
is(ref($t->tgetstr('bl')), 'SCALAR', "\$t->tgetstr('bl')");
is(${$t->tgetstr('bl', \$area)}, '^G', "\$t->tgetstr('bl')");
is($area, '^Gx', "\$t->tgetstr('bl', \\\$area) where \\\$area is \"x\" and its pos() is undef");
is(pos($area), 2, "pos(\\\$area) == 2");
