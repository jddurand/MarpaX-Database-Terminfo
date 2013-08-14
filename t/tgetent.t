#!perl -T
use strict;
use warnings FATAL => 'all';
use Test::More;
use File::Spec;

my $number_of_tests_run = 1;
BEGIN {
    push(@INC, 'inc');
    use_ok( 'MarpaX::Database::Terminfo::Interface', qw/:all/ ) || print "Bail out!\n";
    $ENV{MARPAX_DATABASE_TERMINFO_BIN} = File::Spec->catfile('share', 'ncurses-terminfo.storable');
    $ENV{MARPAX_DATABASE_TERMINFO_CAPS} = File::Spec->catfile('share', 'ncurses-Caps');
}
#
# Test all terminals in the ncurses database
#
_terminfo_init();
foreach (@{_terminfo_db()}) {
    foreach (@{$_->{alias}}) {
	++$number_of_tests_run;
	is(tgetent($_), 1, "tgetent('$_')");
    }
}
done_testing( $number_of_tests_run );
