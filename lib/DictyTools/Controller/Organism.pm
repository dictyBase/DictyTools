package DictyTools::Controller::Organism;

use strict;
use base 'Mojolicious::Controller';

sub index {
    my ($self) = @_;
    my $config = $self->app->config->{organism};
    my $array;
    for my $organism ( $self->organisms_in_db ) {

        # skip if given in the config
        next if exists $config->{ $organism->common_name }->{skip};

        my $prefix = $organism->identifier_prefix;
        if (defined $config->{ $organism->common_name }->{identifier_prefix} )
        {
            $prefix
                = $config->{ $organism->common_name }->{identifier_prefix};
        }
        push @$array,
            {
            display => $organism->name_for_display,
            species => $organism->species,
            genus   => $organism->genus,
            common_name => $organism->common_name,
            identifier_prefix => $prefix
            };
    }
    $self->render( json => $array );
}

1;
