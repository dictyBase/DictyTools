package dictyTools::Controller::Converter;

use strict;
use warnings;
use IO::String;

use base 'Mojolicious::Controller';

use version; 
our $VERSION = qv('2.0.0');

sub index { }

sub convert {
    my ( $self, $c ) = @_;
    my $app = $self->app;

    #set up database connection
    $self->app->set_db_connection if !$self->app->model;

    my $from     = $self->req->param('from');
    my $to       = $self->req->param('to');
    my $ids      = $self->req->param('ids');
    my $organism = $self->req->param('organism');
    return 'organism has to be proivded' if !$organism;

    $self->{connection} = $self->app->model->{$organism};
    my $method = $from . '2' . $to;
    $self->$method($ids);
}

sub gene2features {
    my ( $self, $id ) = @_;

    ## -- get gene by id
    my $gene =
        $self->{connection}->resultset('Sequence::Feature')
        ->find( { 'dbxref.accession' => $id }, { join => 'dbxref' } );

    return 'ID not recognized' if !$gene;
    return 'Gene was deleted'  if $gene->get_column('is_deleted');

    ## -- get primary and genbank features
    my $primary_rs = $self->primary_features($gene);
    $primary_rs = $self->genbank_features($gene) if !$primary_rs->count;

    ## make an array of hashes containing id of the feature and its descriptor
    my @array;
    push @array, map {
        {   id          => $_->dbxref->accession,
            description => $self->description($_)
        }
    } ( $primary_rs->all );

    $self->render( json => \@array );
}

sub description {
    my ( $self, $rs ) = @_;
    my $type = $rs->type->name;

    return 'Curated Gene Model'
        if grep { $_->dbxref->accession =~ m{curator}i } $rs->feature_dbxrefs;
    return 'Predicted Gene Model' if $type eq 'mRNA';
    return 'GenBank Genomic Fragment' if $type =~ m{databank}i;
    return 'GenBank mRNA'             if $type =~ m{cdna}i;
    return $type;
}

sub primary_features {
    my ( $self, $gene ) = @_;

    ## -- get all gene features
    my $sub_rs = $self->app->util->subfeatures($gene);

    ## -- filter out cds, trna, ncrna and pseudogenes
    my $pseudogene_rs =
        $sub_rs->search( { 'type.name' => 'pseudogene' },
        { join => 'type' } );

    my $trna_rs =
        $sub_rs->search( { 'type.name' => 'tRNA' }, { join => 'type' } );

    my $ncrna_rs = $sub_rs->search(
        {   'type.name' => [
                -and => { '!=' => 'mRNA' },
                { '!=' => 'tRNA' }, { 'like', '%RNA' }
            ]
        },
        { join => 'type' }
    );

    return $pseudogene_rs if $pseudogene_rs->count;
    return $trna_rs       if $trna_rs->count;
    return $ncrna_rs      if $ncrna_rs->count;

    ## -- get curated and predicted features
    my $cdss_rs =
        $sub_rs->search( { 'type.name' => 'mRNA' }, { join => 'type' } );

    my $curated_rs = $cdss_rs->search(
        { 'dbxref.accession' => { 'like', '%Curator' } },
        { join => { 'feature_dbxrefs' => 'dbxref' } }
    );

    my $predicted_rs = $cdss_rs->search(
        {   uniquename => {
                'NOT IN' => $curated_rs->get_column('uniquename')->as_query
            }
        }
    );

    return $curated_rs   if $curated_rs->count;
    return $predicted_rs if $predicted_rs->count;
    return;
}

sub genbank_features {
    my ( $self, $gene ) = @_;

    ## -- get all gene features
    my $sub_rs = $self->app->util->subfeatures($gene);

    my $genbank_rs = $sub_rs->search(
        { 'dbxref.accession' => { 'like', '%GenBank%' } },
        { join => [ 'type', { 'feature_dbxrefs' => 'dbxref' } ] },
    );

    return $genbank_rs;
}

sub feature2seqtypes {
    my ( $self, $id ) = @_;

    ## -- get feature by id
    my $feature =
        $self->{connection}->resultset('Sequence::Feature')
        ->find( { 'dbxref.accession' => $id }, { join => 'dbxref' } );

    return 'ID not recognized' if !$feature;
    return 'Feature was deleted' if $feature->get_column('is_deleted');

    my $type      = $feature->type->name;
    my $sequences = {};

    $sequences =
        $type =~ m{mRNA}i
        ? [ 'Protein', 'DNA coding sequence', 'Genomic DNA' ]
        : $type =~ m{Pseudo}i ? [ 'Pseudogene',         'Genomic' ]
        : $type =~ m{RNA}i    ? [ 'Spliced transcript', 'Genomic' ]
        : $type =~ m{EST}i    ? ['EST Sequence']
        :                       undef;
    if ( $type =~ m{cDNA_clone} ) {
        my @seqtypes = ( 'Protein', 'mRNA Sequence', 'DNA coding sequence' );
        foreach my $seqtype (@seqtypes) {
            push @$sequences, $seqtype
                if grep { $_->type->name eq $seqtype } $feature->featureprops;
        }
    }
    elsif ( $type =~ m{databank_entry} ) {
        my @seqtypes = ( 'Protein', 'DNA coding sequence', 'Genomic DNA' );
        foreach my $seqtype (@seqtypes) {
            push @$sequences, $seqtype
                if $self->app->util->get_sequence( $feature, $seqtype );
        }
    }
    $self->render( 'json' => $sequences );
}

1;
