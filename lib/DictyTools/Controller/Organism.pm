package DictyTools::Controller::Organism;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use version; 
our $VERSION = qv('2.0.0');

sub index {
    my ( $self ) = @_;
    my $organism = $self->app->config->{organism};
    my @data = map { $organism->{$_}} keys %$organism;
    $self->render( json => \@data );
}

1;
