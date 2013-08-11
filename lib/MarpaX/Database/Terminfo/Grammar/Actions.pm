use strict;
use warnings FATAL => 'all';

package MarpaX::Database::Terminfo::Grammar::Actions;
use MarpaX::Database::Terminfo::Grammar::Regexp qw/%TOKENSRE/;
use Carp qw/carp/;
use Log::Any qw/$log/;

# ABSTRACT: Terminfo grammar actions

# VERSION

=head1 DESCRIPTION

This modules give the actions associated to terminfo grammar.

=cut

=head2 new($class)

Instance a new object.

=cut

sub new {
    my $class = shift;
    my $self = {_terminfo => [undef]};
    bless($self, $class);
    return $self;
}

=head2 value($self)

Return a parse-tree value.

=cut

sub value {
    my ($self) = @_;
    #
    # Remove the last that was undef
    #
    pop(@{$self->{_terminfo}});

    return $self->{_terminfo};
}

=head2 endTerminfo($self)

Push a new terminfo placeholder.

=cut

sub endTerminfo {
    my ($self) = @_;
    push(@{$self->{_terminfo}}, undef);
}

sub _getTerminfo {
    my ($self) = @_;

    if (! defined($self->{_terminfo}->[-1])) {
	$self->{_terminfo}->[-1] = {alias => [], longname => '', feature => {}};
    }
    return $self->{_terminfo}->[-1];
}

sub _pushFeature {
    my ($self, $type, $feature, $value) = @_;

    my $terminfo = $self->_getTerminfo;

    if (exists($terminfo->{feature}->{$feature})) {
	$log->warnf('%s %s: feature %s overwriten', $terminfo->{alias} || [], $terminfo->{longname} || '', $feature);
    }
    $terminfo->{feature}->{$feature} = {type => $type, value => $value};
}

=head2 longname($self, $longname)

"longname" action.

=cut

sub longname {
    my ($self, $longname) = @_;
    $self->_getTerminfo->{longname} = $longname;
}

=head2 alias($self, $alias)

"alias" action.

=cut

sub alias {
    my ($self, $alias) = @_;
    push(@{$self->_getTerminfo->{alias}}, $alias);
}

=head2 boolean($self, $boolean)

"boolean" action.

=cut

sub boolean {
    my ($self, $boolean) = @_;
    return $self->_pushFeature(0, $boolean, undef);
}

=head2 numeric($self, $numeric)

"numeric" action.

=cut

sub numeric {
    my ($self, $numeric) = @_;

    $numeric =~ /$TOKENSRE{NUMERIC}/;
    return $self->_pushFeature(1, substr($numeric, $-[2], $+[2] - $-[2]), substr($numeric, $-[3], $+[3] - $-[3]));
}

=head2 string($self, $string)

"string" action.

=cut

sub string {
    my ($self, $string) = @_;

    $string =~ /$TOKENSRE{STRING}/;
    return $self->_pushFeature(3, substr($string, $-[2], $+[2] - $-[2]), substr($string, $-[3], $+[3] - $-[3]));
}

1;
