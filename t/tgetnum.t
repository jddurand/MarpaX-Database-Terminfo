#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 2;
use File::Spec;

BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Database::Terminfo::Interface', qw/:functions/ ) || print "Bail out!\n";
    $ENV{MARPAX_DATABASE_TERMINFO_BIN} = File::Spec->catfile('share', 'ncurses-terminfo.storable');
    $ENV{MARPAX_DATABASE_TERMINFO_CAPS} = File::Spec->catfile('share', 'ncurses-Caps');
}
my $t = MarpaX::Database::Terminfo::Interface->new();
$t->tgetent('dumb');
is($t->tgetnum('co'), 80, "\$t->tgetnum('co')");
