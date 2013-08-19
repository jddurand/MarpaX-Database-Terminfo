#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 2;
use File::Spec;
use charnames ':full';

BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Database::Terminfo::Interface', qw/:all/ ) || print "Bail out!\n";
    $ENV{MARPAX_DATABASE_TERMINFO_BIN} = File::Spec->catfile('share', 'ncurses-terminfo.storable');
    $ENV{MARPAX_DATABASE_TERMINFO_CAPS} = File::Spec->catfile('share', 'ncurses-Caps');
    $ENV{MARPAX_DATABASE_TERMINFO_STUBS_BIN} = File::Spec->catfile('share', 'ncurses-terminfo-stubs.storable');
}
my $t = MarpaX::Database::Terminfo::Interface->new();
$t->tgetent('ibcs2');
#
# cm is the cursor adress
#
my $cmp = $t->tgetstr('cm');
is ($t->tgoto(${$cmp}, 18, 40), "\N{ESC}[19;41H", 'ibcs2 cursor_adress');
