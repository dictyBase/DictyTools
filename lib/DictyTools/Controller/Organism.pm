package DictyTools::Controller::Organism;

use strict;
use base 'Mojolicious::Controller';

sub index {
    my ($self) = @_;
    my $config = $self->app->config->{organism};
    my $array;
    for my $organism ( $self->organisms_in_db ) {
        my $prefix = $organism->identifier_prefix;
        if (defined $config->{ $organism->common_name }->{identifier_prefix} )
        {
            $prefix
                = $config->{ $organism->common_name }->{identifier_prefix};
        }
        push @$array,
            {
            display           => $organism->display_name,
            identifier_prefix => $prefix
            };
    }
    $self->render( json => $array );
}

1;
