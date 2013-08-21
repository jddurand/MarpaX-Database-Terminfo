#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 11;
use File::Spec;

BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Database::Terminfo::Interface', qw/:functions/ ) || print "Bail out!\n";
    $ENV{MARPAX_DATABASE_TERMINFO_BIN} = File::Spec->catfile('share', 'ncurses-terminfo.storable');
    $ENV{MARPAX_DATABASE_TERMINFO_CAPS} = File::Spec->catfile('share', 'ncurses-Caps');
    $ENV{MARPAX_DATABASE_TERMINFO_STUBS_BIN} = File::Spec->catfile('share', 'ncurses-terminfo-stubs.storable');
}
my $t = MarpaX::Database::Terminfo::Interface->new();
$t->tgetent('dumb');
my $area;
is($t->tvgetstr('notexisting', \$area), 0, "\$t->tvgetstr('notexisting', \\\$area) returns false");
is($t->tvgetstr('bell', \$area), 1, "\$t->tvgetstr('bell', \\\$area) returns true");
is($area, '^G', "\$area value");
is(pos($area), 2, "pos(\\\$area) == 2");
$area = 'x';
pos($area) = length($area);
is($t->tvgetstr('bell', \$area), 1, "\$t->tvgetstr('bell', \\\$area) returns true");
is($area, 'x^G', "\$area value where \\\$area was \"x\" and pos() 1");
is(pos($area), 3, "pos(\\\$area) == 3");
$area = 'x';
pos($area) = undef;
is($t->tvgetstr('bell', \$area), 1, "\$t->tvgetstr('bell', \\\$area) returns true");
is($area, '^Gx', "\$area value where \\\$area was \"x\" and pos() undef");
is(pos($area), 2, "pos(\\\$area) == 2");
