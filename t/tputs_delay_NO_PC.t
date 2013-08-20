#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More tests => 2;
use charnames ':full';
use File::Spec;

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
# cup is the cursor adress
#
my $cupp = $t->tigetstr('cup');
my $got = '';
my $wanted = chr(27) . chr(91) . chr(49) . chr(57) . chr(59) . chr(52) . chr(49) . chr(72) . chr(0);
$t->tputs($t->tgoto(${$cupp} . '$<1000>', 40, 18), 1, \&outc);
is($got, $wanted, 'cup at 18:40 under terminal ibcs2 that have no pad_char'); 

sub outc {
    my ($c) = @_;
    if ($c) {
	$got .= $c;
    } else {
	$got .= chr(0);
    }
}
