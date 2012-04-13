package DictyTools::Controller::Converter;

use strict;
use warnings;
use IO::String;

use base 'Mojolicious::Controller';

use version;
our $VERSION = qv('2.0.0');

sub index { }

sub convert {
    my ($self) = @_;
    my $app = $self->app;

    my $from     = $self->req->param('from');
    my $to       = $self->req->param('to');
    my $ids      = $self->req->param('ids');
    my $organism = $self->req->param('organism');
    return 'organism has to be proivded' if !$organism;

    my $method
        = $organism eq 'discoideum'
        ? 'discoideum_' . $from . '2' . $to
        : $from . '2' . $to;
    my $data = $self->$method( $ids, $self->get_model($organism) );
    $self->render( json => $data );
}

sub discoideum_gene2features {
    my ( $self, $id, $connection ) = @_;

    ## -- get gene by id
    my $gene = $connection->resultset('Sequence::Feature')
        ->find( { 'dbxref.accession' => $id }, { join => 'dbxref' } );

    return 'ID not recognized' if !$gene;
    return 'Gene was deleted'  if $gene->get_column('is_deleted');

    ## -- get primary and genbank features
    my $primary_rs = $self->primary_features($gene);
    $primary_rs = $self->genbank_features($gene) if !$primary_rs;

    ## make an array of hashes containing id of the feature and its descriptor
    my @array;
    push @array, map {
        {   id          => $_->dbxref->accession,
            description => $self->discoideum_description($_)
        }
    } ( $primary_rs->all );

    return \@array;
}

sub discoideum_description {
    my ( $self, $rs ) = @_;
    my $type = $rs->type->name;

    return 'Curated Gene Model'
        if grep { $_->dbxref->accession =~ m{curator}i } $rs->feature_dbxrefs;
    return 'Predicted Gene Model' if $type eq 'mRNA';
    return 'GenBank Genomic Fragment' if $type =~ m{databank}i;
    return 'GenBank mRNA'             if $type =~ m{cdna}i;
    return $type;
}

sub gene2features {
    my ( $self, $id, $connection ) = @_;

    ## -- get gene by id
    my $gene = $connection->resultset('Sequence::Feature')
        ->find( { 'dbxref.accession' => $id }, { join => 'dbxref' } );

    return 'ID not recognized' if !$gene;

    ## -- get primary and genbank features
    my $transcript_rs = $gene->search_related(
        'feature_relationship_objects',
        { 'type.name' => 'part_of' },
        { join        => 'type' }
        )->search_related(
        'subject',
        { 'type_2.name' => { -like => '%RNA' } },
        { join          => 'type' }
        );

    ## make an array of hashes containing id of the feature and its descriptor
    my $array = [
        map {
            {   id          => $_->dbxref->accession,
                description => $self->description($_)
            }
            } $transcript_rs->all
    ];
    return $array if @$array;
}

sub description {
    my ( $self, $row ) = @_;
    my $source
        = $row->search_related( 'feature_dbxrefs', {} )->search_related(
        'dbxref',
        { 'db.name' => 'GFF_source' },
        { join      => 'db' }
        )->first->accession;
    return $source . ' Gene Model';
}

sub primary_features {
    my ( $self, $gene ) = @_;

    ## -- get all gene features
    my $sub_rs = $self->subfeatures($gene);

    ## -- filter out cds, trna, ncrna and pseudogenes
    my $pseudogene_rs = $sub_rs->search( { 'type.name' => 'pseudogene' },
        { join => 'type' } );

    my $trna_rs
        = $sub_rs->search( { 'type.name' => 'tRNA' }, { join => 'type' } );

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
    my $cdss_rs
        = $sub_rs->search( { 'type.name' => 'mRNA' }, { join => 'type' } );

    my $curated_rs = $cdss_rs->search(
        { 'dbxref.accession' => { 'like',           '%Curator' } },
        { join               => { 'feature_dbxrefs' => 'dbxref' } }
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
    my $sub_rs = $self->subfeatures($gene);

    my $genbank_rs = $sub_rs->search(
        { 'dbxref.accession' => { 'like', '%GenBank%' } },
        { join => [ 'type', { 'feature_dbxrefs' => 'dbxref' } ] },
    );

    return $genbank_rs;
}

sub discoideum_feature2seqtypes {
    my ( $self, $id, $connection ) = @_;

    ## -- get feature by id
    my $feature = $connection->resultset('Sequence::Feature')
        ->find( { 'dbxref.accession' => $id }, { join => 'dbxref' } );

    return 'ID not recognized'   if !$feature;
    return 'Feature was deleted' if $feature->get_column('is_deleted');

    my $type      = $feature->type->name;
    my $sequences = {};

    $sequences
        = $type =~ m{mRNA}i
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
                if $self->get_sequence( $feature, $seqtype );
        }
    }
    return $sequences;
}

sub feature2seqtypes {
    my ( $self, $id, $connection ) = @_;

    ## -- get feature by id
    my $feature = $connection->resultset('Sequence::Feature')
        ->find( { 'dbxref.accession' => $id }, { join => 'dbxref' } );

    return 'ID not recognized' if !$feature;

    my $type = $feature->type->name;
    my $sequences
        = $type =~ m{mRNA}i
        ? [ 'Protein', 'DNA coding sequence', 'Genomic DNA' ]
        : $type =~ m{RNA}i ? [ 'Spliced transcript', 'Genomic' ]
        : $type =~ m{EST}i ? ['EST Sequence']
        :                    undef;
    return $sequences;
}

1;
