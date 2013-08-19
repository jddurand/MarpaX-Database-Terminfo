use strict;
use warnings FATAL => 'all';

#
# This module is sharing the same mechanism as MarpaX::Database::Terminfo
#
package MarpaX::Database::Terminfo::String;
use base 'MarpaX::Database::Terminfo';
use MarpaX::Database::Terminfo::String::Grammar;
use Marpa::R2;

# ABSTRACT: Parse a terminfo string using Marpa

use Log::Any qw/$log/;
use Carp qw/croak/;

# VERSION

=head1 DESCRIPTION

This module parses a terminfo string and produces an anonymous subroutine from it. If you want to enable logging, be aware that this module is a Log::Any thingy. This module is inheriting the value() method from MarpaX::Database::Terminfo.

=head1 SYNOPSIS

    use strict;
    use warnings FATAL => 'all';
    use MarpaX::Database::Terminfo::String;
    use Log::Log4perl qw/:easy/;
    use Log::Any::Adapter;
    use Log::Any qw/$log/;
    #
    # Init log
    #
    our $defaultLog4perlConf = '
    log4perl.rootLogger              = WARN, Screen
    log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
    log4perl.appender.Screen.stderr  = 0
    log4perl.appender.Screen.layout  = PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern = %d %-5p %6P %m{chomp}%n
    ';
    Log::Log4perl::init(\$defaultLog4perlConf);
    Log::Any::Adapter->set('Log4perl');
    #
    # Parse terminfo
    #
    my $stringSourceCode = "\\E[%i%p1%d;%p2%dH";
    my $stringSubObject = MarpaX::Database::Terminfo::String->new();
    my $stringSub = stringSubObject->parse(\$stringSourceCode)->value;

=cut

=head1 SUBROUTINES/METHODS

=cut

# ----------------------------------------------------------------------------------------
=head2 new($class)

Instantiate a new object. Takes no parameter.

=cut

sub new {
  my $class = shift;

  my $self = {};

  my $grammarObj = MarpaX::Database::Terminfo::String::Grammar->new(@_);
  my $grammar_option = $grammarObj->grammar_option();
  $grammar_option->{bless_package} = __PACKAGE__;
  $self->{_G} = Marpa::R2::Scanless::G->new($grammar_option);

  my $recce_option = $grammarObj->recce_option();
  $recce_option->{grammar} = $self->{_G};
  $self->{_R} = Marpa::R2::Scanless::R->new($recce_option);

  bless($self, $class);

  return $self;
}
# ----------------------------------------------------------------------------------------
=head2 parse($self, $bufferp)

Parses a terminfo database. Takes a pointer to a string as parameter.

=cut

sub parse {
    my ($self, $bufferp) = @_;
    #
    # No array reference argument: this grammar has no event
    #
    return $self->_parse($bufferp);
}

=head1 SEE ALSO

L<Unix Documentation Project - terminfo|http://nixdoc.net/man-pages/HP-UX/man4/terminfo.4.html#Formal%20Grammar>

L<GNU Ncurses|http://www.gnu.org/software/ncurses/>

=cut

1;
