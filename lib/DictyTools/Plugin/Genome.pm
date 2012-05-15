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
        'organims_in_db' => sub {
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
                common_name          => $row->common_name,
                species              => $row->species,
                genus                => $row->genus
                    name_for_display => sprintf "%s %s",
                $row->genus,
                $self->normalize_for_display( $self->species )
                );
        }
    }
    $common_name2org->{discoideum} = DictyTools::Organism->new(
        common_name      => 'discoideum',
        species          => 'discoideum',
        genus            => 'Dictyostelium',
        name_for_display => 'Dictyostelium discoideum'
    ) if not exists $common_name2org->{discoideum};
    $self->common_name2org_map($common_name2org);

    return [
        sort {
                   $a->genus cmp $b->genus
                || $a->common_name cmp $b->common_name
            } values %$common_name2org
    ];
}

sub normalize_for_display {
	my ($self, $name) = @_;
	if ($name =~ /^(\w+)\s+\w+/) {
		return $1;
	}
	return $name;
}

1;
