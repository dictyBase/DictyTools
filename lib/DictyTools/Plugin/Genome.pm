package DictyTools::Plugin::Genome;

use strict;
use Mojo::Base -base;
use Mojo::Base 'Mojolicious::Plugin';
use DictyTools::Organism;

has '_organisms';

sub register {
    my ( $self, $app ) = @_;
    if ( $app->can('model') ) {
        $self->_organisms( $self->_organisms_from_db( $app->model, $app ) );
    }
    $app->helper(
        'organisms_in_db' => sub {
            my ($c) = @_;
            if ( !$self->_organisms ) {
                $self->_organisms(
                    $self->_organisms_from_db( $c->app->model, $c->app ) );
            }
            return @{ $self->_organisms };
        }
    );
}

sub _organisms_from_db {
    my ( $self, $model, $app ) = @_;
    my $common_name2org;
    my $rs = $model->resultset('Organism::Organism')->search(
        {   'type.name' => 'loaded_genome',
            'cv.name'   => 'genome_properties'
        },
        { join => [ { 'organismprops' => { 'type' => 'cv' } } ], }
    );

    while ( my $row = $rs->next ) {
        if ( not exists $common_name2org->{ $row->common_name } ) {

            my $display_name = sprintf "%s %s", $row->genus,
                $self->normalize_for_display( $row->species );
            my $prefix
                = substr( $row->genus, 0, 1 ) . substr( $row->species, 0, 2 );

            $common_name2org->{ $row->common_name }
                = DictyTools::Organism->new(
                common_name       => $row->common_name,
                species           => $row->species,
                genus             => $row->genus,
                name_for_display  => $display_name,
                identifier_prefix => uc $prefix
                );
        }
    }
    $common_name2org->{discoideum} = DictyTools::Organism->new(
        common_name      => 'discoideum',
        species          => 'discoideum',
        genus            => 'Dictyostelium',
        name_for_display => 'Dictyostelium discoideum'
    ) if not exists $common_name2org->{discoideum};

    return [
        sort {
                   $a->genus cmp $b->genus
                || $a->common_name cmp $b->common_name
            } values %$common_name2org
    ];
}

sub normalize_for_display {
    my ( $self, $name ) = @_;
    if ( $name =~ /^(\w+)\s+\w+/ ) {
        return $1;
    }
    return $name;
}

1;
