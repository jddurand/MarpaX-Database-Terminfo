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

sub InCommaSlashPipe {
    return <<END;
$COMMA_HEX
$SLASH_HEX
$PIPE_HEX
END
}

sub InCommaPipe {
    return <<END;
$COMMA_HEX
$PIPE_HEX
END
}

sub InPipe {
    return <<END;
$PIPE_HEX
END
}

sub InCommaEqualPound {
    return <<END;
$COMMA_HEX
$EQUAL_HEX
$POUND_HEX
END
}

sub InComma {
    return <<END;
$COMMA_HEX
END
}

sub InAlias {
    return <<END;
+utf8::IsGraph
-MarpaX::Database::Terminfo::Grammar::CharacterClasses::InCommaSlashPipe
END
}

sub InLongname {
    return <<END;
+utf8::IsPrint
-MarpaX::Database::Terminfo::Grammar::CharacterClasses::InCommaPipe
END
}

sub InNcursesLongname {
    return <<END;
+utf8::IsPrint
-MarpaX::Database::Terminfo::Grammar::CharacterClasses::InPipe
END
}

sub InName {
    return <<END;
+utf8::IsPrint
-MarpaX::Database::Terminfo::Grammar::CharacterClasses::InCommaEqualPound
END
}

sub InIsPrintExceptComma {
    return <<END;
+utf8::IsPrint
-MarpaX::Database::Terminfo::Grammar::CharacterClasses::InComma
END
}

sub InIsPrintAndIsGraph {
    return <<END;
+utf8::IsPrint
+utf8::IsGraph
END
}

1;
