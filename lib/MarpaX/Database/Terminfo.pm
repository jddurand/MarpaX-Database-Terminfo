use strict;
use warnings FATAL => 'all';

package MarpaX::Database::Terminfo;
use MarpaX::Database::Terminfo::Grammar;
use MarpaX::Database::Terminfo::Grammar::CharacterClasses;
use Marpa::R2;

# ABSTRACT: Parse a terminfo data base using Marpa

use Log::Any qw/$log/;
use Carp qw/croak/;

# VERSION

sub new {
  my $class = shift;

  my $self = {};

  my $grammarObj = MarpaX::Database::Terminfo::Grammar->new(@_);
  $self->{_G} = Marpa::R2::Scanless::G->new({source => \$grammarObj->content, bless_package => __PACKAGE__});
  $self->{_R} = Marpa::R2::Scanless::R->new({grammar => $self->{_G}});

  bless($self, $class);

  return $self;
}

our $I_CONSTANT = qr/(?:(0[xX][a-fA-F0-9]+(?:[uU](?:ll|LL|[lL])?|(?:ll|LL|[lL])[uU]?)?)             # Hexadecimal
                      |([1-9][0-9]*(?:[uU](?:ll|LL|[lL])?|(?:ll|LL|[lL])[uU]?)?)                    # Decimal
                      |(0[0-7]*(?:[uU](?:ll|LL|[lL])?|(?:ll|LL|[lL])[uU]?)?)                        # Octal
                      |([uUL]?'(?:[^'\\\n]|\\(?:[\'\"\?\\abfnrtv]|[0-7]{1..3}|x[a-fA-F0-9]+))+')    # Character
                    )/x;

#
# It is important to have LONGNAME before ALIAS because LONGNAME will do a lookahead on COMMA
# It is important to have NUMERIC and STRING before BOOLEAN because BOOLEAN is a subset of them
#
our @TOKENSRE = (
    [ 'ALIASINCOLUMNONE' , qr/\G^(\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InAlias}+)/ ],
    [ 'PIPE'             , qr/\G(\|)/ ],
    [ 'LONGNAME'         , qr/\G(\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InLongname}+),/ ],
    [ 'ALIAS'            , qr/\G(\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InAlias}+)/ ],
    [ 'NUMERIC'          , qr/\G(\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InName}+#$I_CONSTANT)/ ],
    [ 'STRING'           , qr/\G(\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InName}+=\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InIsPrintExceptComma}+)/ ],
    [ 'BOOLEAN'          , qr/\G(\p{MarpaX::Database::Terminfo::Grammar::CharacterClasses::InName}+)/ ],
    [ 'COMMA'            , qr/\G(, ?)/ ],
    );

my %events = (
    'MAXMATCH' => sub {
        my ($recce, $bufferp, $string, $start, $length) = @_;

	my @expected = @{$recce->terminals_expected()};
	my $prev = pos(${$bufferp});
	pos(${$bufferp}) = $start;
	my $ok = 0;
	# print STDERR "@expected\n";
	foreach (@TOKENSRE) {
	    my ($token, $re) = @{$_};
	    if ((grep {$_ eq $token} @expected) && ${$bufferp} =~ $re) {
		$length = $+[1] - $-[1];
		$string = substr(${$bufferp}, $start, $length);
		# print "OK: $token $string\n";
		$recce->lexeme_read($token, $start, $length, $string);
		$ok = 1;
		last;
	    }
	}
	die "Unmatched token in @expected" if (! $ok);
	pos(${$bufferp}) = $prev;
    },
);
sub parse {
    my ($self, $bufferp) = @_;

    my $max = length(${$bufferp});
    for (
        my $pos = $self->{_R}->read($bufferp);
        $pos < $max;
        $pos = $self->{_R}->resume()
    ) {
        my ($start, $length) = $self->{_R}->pause_span();
        my $str = substr(${$bufferp}, $start, $length);
        for my $event_data (@{$self->{_R}->events}) {
            my ($name) = @{$event_data};
            my $code = $events{$name} // die "no code for event $name";
            $self->{_R}->$code($bufferp, $str, $start, $length);
        }
    }
}

sub value {
    my ($self) = @_;

    return $self->{_R}->value();
}

1;
