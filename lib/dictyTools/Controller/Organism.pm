package dictyTools::Controller::Organism;

use strict;
use warnings;
use base qw/Mojolicious::Controller/;

sub index {
    my ( $self, $c ) = @_;
    my $organism = $self->app->config->{organism};
    my @data = map { $organism->{$_}} keys %$organism;
    $self->render( json => \@data );
}

1;
