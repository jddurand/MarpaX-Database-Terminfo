use strict;
use warnings FATAL => 'all';

package MarpaX::Database::Terminfo::Constants;
use Exporter 'import';
use charnames ':full';

use constant TERMINFO_BOOLEAN => 0;
use constant TERMINFO_NUMERIC => 1;
use constant TERMINFO_STRING  => 2;

our @EXPORT_TYPES = qw/TERMINFO_BOOLEAN TERMINFO_NUMERIC TERMINFO_STRING/;

#
# We use ISO 6429 names as stated per perldoc charnames
#
use constant TERMINFO_ESC => "\N{ESC}";
use constant TERMINFO_NL  => "\n";  # There is no newline formally. This is mapped to platform dependent "newline"-thingy
use constant TERMINFO_LF  => "\N{LF}";
use constant TERMINFO_CR  => "\N{CR}";
use constant TERMINFO_TAB => "\N{HT}";
use constant TERMINFO_BS  => "\N{BS}";
use constant TERMINFO_FF  => "\N{FF}";
use constant TERMINFO_SP  => "\N{SPACE}";

our @EXPORT_CHARS = qw/TERMINFO_ESC
                       TERMINFO_NL
                       TERMINFO_LF
                       TERMINFO_CR
                       TERMINFO_TAB
                       TERMINFO_BS
                       TERMINFO_FF
                       TERMINFO_SP/;

our @EXPORT_OK = (@EXPORT_TYPES, @EXPORT_CHARS);
our %EXPORT_TAGS = ('all'       => \@EXPORT_OK,
		    'chars'     => \@EXPORT_CHARS,
		    'types'     => \@EXPORT_TYPES);

# ABSTRACT: Terminfo constants

# VERSION

=head1 DESCRIPTION

This modules export terminfo interface constants.

=head1 SYNOPSIS

    use MarpaX::Database::Terminfo::Constants qw/:all/;

    my $terminfo_boolean = TERMINFO_BOOLEAN;
    my $terminfo_ff = TERMINFO_FF;

=head1 EXPORTS

This module is exporting on demand the following tags:

=over

=item types

The constants TERMINFO_BOOLEAN, TERMINFO_NUMERIC and TERMINFO_STRING.

=item chars

The constants TERMINFO_ESC (escape character), TERMINFO_NL (newline character - OS dependent), TERMINFO_LF (line feed), TERMINFO_CR (carriage return), TERMINFO_TAB (tab), TERMINFO_BS (backspace), TERMINFO_FF (form feed), TERMINFO_SP (space).

=item all

All of the above.

=back

=head1 SEE ALSO

L<Unix Documentation Project - terminfo|http://nixdoc.net/man-pages/HP-UX/man4/terminfo.4.html#Formal%20Grammar>

L<GNU Ncurses|http://www.gnu.org/software/ncurses/>

=cut

1;

__DATA__
