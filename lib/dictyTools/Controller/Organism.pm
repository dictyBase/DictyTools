package dictyTools::Controller::Organism;

use strict;
use warnings;
use base qw/Mojolicious::Controller/;
#use ModConfig;

sub index {
    my ( $self, $c ) = @_;
    my $conf = ModConfig->load();
    #my $organism = $conf->obj('ORGANISMS')->value('ORGANISM');
    #now rendering
    my $organism = $self->app->config->{organism};
    my @data = map { $organism->{$_}} keys %$organism;
    $self->render( handler => 'json', data => \@data );
}

1;
