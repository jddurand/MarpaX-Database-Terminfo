use strict;
use warnings FATAL => 'all';

package MarpaX::Database::Terminfo::Grammar::CharacterClasses;

# ABSTRACT: Terminfo character classes

# VERSION

=head1 DESCRIPTION

This modules describes Terminfo character classes

=cut

our $COMMA_HEX  = sprintf('%x', ord(','));
our $SLASH_HEX  = sprintf('%x', ord('/'));
our $PIPE_HEX   = sprintf('%x', ord('|'));
our $EQUAL_HEX  = sprintf('%x', ord('='));
our $POUND_HEX  = sprintf('%x', ord('#'));

=head2 InCommaSlashPipe()

Character class for ',', '/' and '|'.

=cut

sub InCommaSlashPipe {
    return <<END;
$COMMA_HEX
$SLASH_HEX
$PIPE_HEX
END
}

=head2 InCommaPipe()

Character class for ',' and '|'.

=cut

sub InCommaPipe {
    return <<END;
$COMMA_HEX
$PIPE_HEX
END
}

=head2 InPipe()

Character class for '|'.

=cut

sub InPipe {
    return <<END;
$PIPE_HEX
END
}

=head2 InCommaEqualPound()

Character class for ',', '=' and '#'

=cut

sub InCommaEqualPound {
    return <<END;
$COMMA_HEX
$EQUAL_HEX
$POUND_HEX
END
}

=head2 InComma()

Character class for ','

=cut

sub InComma {
    return <<END;
$COMMA_HEX
END
}

=head2 InAlias()

Character class for a terminfo alias.

=cut

sub InAlias {
    return <<END;
+utf8::IsGraph
-MarpaX::Database::Terminfo::Grammar::CharacterClasses::InCommaSlashPipe
END
}

=head2 InLongname()

Character class for a terminfo long name.

=cut

sub InLongname {
    return <<END;
+utf8::IsPrint
-MarpaX::Database::Terminfo::Grammar::CharacterClasses::InCommaPipe
END
}

=head2 InNcursesLongname()

Character class for a (ncurses) terminfo long name.

=cut

sub InNcursesLongname {
    return <<END;
+utf8::IsPrint
-MarpaX::Database::Terminfo::Grammar::CharacterClasses::InPipe
END
}

=head2 InName()

Character class for a terminfo capability name.

=cut

sub InName {
    return <<END;
+utf8::IsPrint
-MarpaX::Database::Terminfo::Grammar::CharacterClasses::InCommaEqualPound
END
}

=head2 InIsPrintExceptComma()

Character class for a isprint character except ','.

=cut

sub InIsPrintExceptComma {
    return <<END;
+utf8::IsPrint
-MarpaX::Database::Terminfo::Grammar::CharacterClasses::InComma
END
}

=head2 InIsPrintAndIsGraph()

Character class for a isprint or isgraph character

=cut

sub InIsPrintAndIsGraph {
    return <<END;
+utf8::IsPrint
+utf8::IsGraph
END
}

1;
