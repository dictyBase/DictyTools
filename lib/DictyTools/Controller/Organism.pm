package DictyTools::Controller::Organism;

use strict;
use warnings;

use base 'Mojolicious::Controller';

use version;
our $VERSION = qv('2.0.0');

sub index {
    my ($self)   = @_;
    my $organism = $self->app->config->{organism};

    my $array;
    for my $name ( keys %$organism ) {
        my $hash;
        my $common_name
            = $organism->{$name}->{common_name}
            ? $organism->{$name}->{common_name}
            : $name;
        my $org = $self->get_model($organism)->resultset('Organism::Organism')
            ->search( { 'common_name' => $common_name } )->first;

		if (defined $organism->{name}->{display}) {
			$hash->{display} = $organism->{name}->{display};
		}
        elsif ( defined $organism->{$name}->{process} ) {
            my ($species) = ( ( split /\s+/, $org->species ) )[0];
            $hash->{display} = $org->genus . ' ' . $species;
        }
        else {
            $hash->{display} = $org->genus . ' ' . $org->species;
        }
        for my $val(qw/taxon_id identifier_prefix site_url/) {
        	$hash->{$val} = $organism->{$name}->{$val};
        }
        push @$array, $hash;
    }
    $self->render( json => $array );
}

1;
