use strict;
use warnings FATAL => 'all';

package MarpaX::Database::Terminfo::Grammar;

# ABSTRACT: Terminfo grammar in Marpa BNF

# VERSION

=head1 DESCRIPTION

This modules returns Terminfo grammar written in Marpa BNF.

=head1 SYNOPSIS

    use MarpaX::Database::Terminfo::Grammar;

    my $grammar = MarpaX::Database::Terminfo::Grammar->new();
    my $grammar_content = $grammar->content();

=head1 SUBROUTINES/METHODS

=head2 new($class)

Instance a new object.

=cut

sub new {
  my $class = shift;

  my $self = {};

  $self->{_content} = do {local $/; <DATA>};

  bless($self, $class);

  return $self;
}

=head2 content($self)

Returns the content of the grammar.

=cut

sub content {
    my ($self) = @_;
    return $self->{_content};
}

=head1 SEE ALSO

L<Marpa::R2>

=cut

1;

__DATA__
#
# G1 As per http://nixdoc.net/man-pages/HP-UX/man4/terminfo.4.html#Formal%20Grammar
# ---------------------------------------------------------------------------------
:default ::= action => [values] bless => ::lhs

:start ::= descriptions

descriptions ::= startOfHeaderLine restOfHeaderLine featureLines
               | descriptions startOfHeaderLine restOfHeaderLine
               | featureLines

restOfHeaderLine ::= (pipe) longname (comma NEWLINE)
                   | aliases (pipe) longname (comma NEWLINE)

featureLines ::= featureLine+

featureLine ::= startFeatureLine features (comma NEWLINE)
              | startFeatureLine (comma NEWLINE)

startFeatureLine ::= startFeatureLineBoolean
                   | startFeatureLineNumeric
                   | startFeatureLineString

features ::= feature+

aliases ::= (pipe) alias
          | aliases (pipe) alias

feature ::= (comma) boolean
          | (comma) numeric
          | (comma) string

#
# Special cases
#
startOfHeaderLine       ::= aliasInColumnOne
startFeatureLineBoolean ::= (WS_many) boolean
startFeatureLineNumeric ::= (WS_many) numeric
startFeatureLineString  ::= (WS_many) string

#
# G0
# --
PIPE                  ~ '|'
WS                    ~ [ \t]
WS_maybe              ~ WS
WS_maybe              ~
WS_any                ~ WS*
WS_many               ~ WS+
COMMA                 ~ ',' WS_maybe
POUND                 ~ '#'
EQUAL                 ~ '='
_NEWLINE              ~ [\n]
NEWLINE               ~ _NEWLINE
NOT_NEWLINE_any       ~ [^\n]*

_NAME                 ~ [\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InName}]+
_ALIAS                ~ [\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InAlias}]+
_LONGNAME             ~ [\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InLongname}]+
_INISPRINTEXCEPTCOMMA ~ [\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InIsPrintExceptComma}]+

ALIAS                 ~ _ALIAS
ALIASINCOLUMNONE      ~ _ALIAS
LONGNAME              ~ _LONGNAME
BOOLEAN               ~ _NAME
NUMERIC               ~ _NAME POUND I_CONSTANT
STRING                ~ _NAME EQUAL _INISPRINTEXCEPTCOMMA

alias                 ::= MAXMATCH | ALIAS
aliasInColumnOne      ::= MAXMATCH | ALIASINCOLUMNONE
longname              ::= MAXMATCH | LONGNAME
boolean               ::= MAXMATCH | BOOLEAN
numeric               ::= MAXMATCH | NUMERIC
string                ::= MAXMATCH | STRING
pipe                  ::= MAXMATCH | PIPE
comma                 ::= MAXMATCH | COMMA

COMMENT               ~ WS_any POUND NOT_NEWLINE_any _NEWLINE
:discard              ~ COMMENT
BLANKLINE             ~ WS_any _NEWLINE
:discard              ~ BLANKLINE
#
# I_CONSTANT from C point of view
#
I_CONSTANT ~ HP H_many IS_maybe
           | NZ D_any IS_maybe
           | '0' O_any IS_maybe
           | CP_maybe QUOTE I_CONSTANT_INSIDE_many QUOTE
HP         ~ '0' [xX]
H          ~ [a-fA-F0-9]
H_many     ~ H+
LL         ~ 'll' | 'LL' | [lL]
LL_maybe   ~ LL
LL_maybe   ~
U          ~ [uU]
U_maybe    ~ U
U_maybe    ~
IS         ~ U LL_maybe | LL U_maybe
IS_maybe   ~ IS
IS_maybe   ~
NZ         ~ [1-9]
D          ~ [0-9]
D_any      ~ D*
O          ~ [0-7]
O_any      ~ O*
CP         ~ [uUL]
CP_maybe   ~ CP
CP_maybe   ~
QUOTE     ~ [']
I_CONSTANT_INSIDE ~ [^'\\\n]
I_CONSTANT_INSIDE ~ ES
I_CONSTANT_INSIDE_many ~ I_CONSTANT_INSIDE+
BS         ~ '\'
ES_AFTERBS ~ [\'\"\?\\abfnrtv]
           | O
           | O O
           | O O O
           | 'x' H_many
ES         ~ BS ES_AFTERBS
#
# Following http://stackoverflow.com/questions/17773976/prevent-naive-longest-token-matching-in-marpar2scanless we
# will always match a longer substring than the one originally wanted.
#
:lexeme ~ MAXMATCH pause => before event => MAXMATCH
MAXMATCH   ~ [\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InIsPrintAndIsGraph}]+
