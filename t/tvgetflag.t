#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 3;
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
is($t->tvgetflag('notexisting'), 0, "\$t->tvgetflag('notexisting') returns false");
is($t->tvgetflag('auto_right_margin'), 1, "\$t->tvgetflag('auto_right_margin') returns true");
