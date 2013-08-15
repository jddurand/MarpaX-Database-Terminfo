#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 5;
use File::Spec;

BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Database::Terminfo::Interface', qw/:all/ ) || print "Bail out!\n";
    $ENV{MARPAX_DATABASE_TERMINFO_BIN} = File::Spec->catfile('share', 'ncurses-terminfo.storable');
    $ENV{MARPAX_DATABASE_TERMINFO_CAPS} = File::Spec->catfile('share', 'ncurses-Caps');
}
my $t = MarpaX::Database::Terminfo::Interface->new();
$t->tgetent('nsterm-16color');
is($t->tigetnum('wsl'), 50, "\$t->tigetnum('wsl') - numeric value");
is($t->tigetnum('fsl'), -2, "\$t->tigetnum('fsl') - not a numeric capability");
is($t->tigetnum('absentcap'), -1, "\$t->tigetnum('absentcap') - absent capability ");
is($t->tigetnum('bw'), -1, "\$t->tigetflag('bw') - cancelled capability");
