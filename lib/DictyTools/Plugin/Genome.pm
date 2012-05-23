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
    $app->helper(
        genome2browser_url => sub {
            my ( $c, $org ) = @_;
            my $common_name  = $org->common_name;
            my $gbrowse_base = $c->app->config->{gbrowse_url} . '/gbrowse';

            if ( $common_name eq 'discoideum' ) {
                return $gbrowse_base . '/discoideum?name=6:1..50000';
            }

            # -- get a random reference feature
            my $rs
                = $c->app->model->resultset('Organism::Organism')
                ->search( { 'common_name' => $common_name } )->search_related(
                'features',
                { 'type.name' => 'gene' },
                { join        => 'type' }
                )->search_related( 'featureloc_features', {} )
                ->search_related( 'srcfeature',           {},
                { order_by => \'dbms_random.value' } );

            my $row     = $rs->first;
            my $end     = $row->seqlen > 50000 ? 50000 : $row->seqlen;
            my $qstring = 'name=' . $self->_chado_name($row) . ':1..' . $end;
            my $str     = "$gbrowse_base/$common_name?$qstring";
            return $str;
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

sub _chado_name {
    my ( $self, $row ) = @_;
    return $row->name ? $row->name : $row->uniquename;
}

1;
