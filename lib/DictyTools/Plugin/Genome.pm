package DictyTools::Plugin::Genome;

use strict;
use Mojo::Base -base;
use Mojo::Base 'Mojolicious::Plugin';
use DictyTools::Organism;

has '_genomes';

sub register {
    my ( $self, $app ) = @_;
    if ( $app->can('model') ) {
        $self->_genomes( $self->_genomes_from_db( $app->model, $app ) );
    }
    $app->helper(
        loaded_genomes => sub {
            my ($c) = @_;
            if ( !$self->_genomes ) {
                $self->_genomes(
                    $self->_genomes_from_db( $c->app->model, $app ) );
            }
            my $genomes = $self->_genomes;
            return @$genomes;
        }
    );
}

sub _genomes_from_db {
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
            $common_name2org->{ $row->common_name }
                = DictyTools::Organism->new(
                common_name => $row->common_name,
                species     => $row->species,
                genus       => $row->genus
                );
        }
    }
    $common_name2org->{discoideum} = DictyTools::Organism->new(
        common_name => 'discoideum',
        species     => 'discoideum',
        genus       => 'Dictyostelium'
    ) if not exists $common_name2org->{discoideum};
    $self->common_name2org_map($common_name2org);

    return [
        sort {
                   $a->genus cmp $b->genus
                || $a->common_name cmp $b->common_name
            } values %$common_name2org
    ];
}

1;
