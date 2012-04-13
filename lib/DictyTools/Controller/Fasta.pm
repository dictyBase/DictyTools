package DictyTools::Controller::Fasta;

use strict;
use warnings;
use IO::String;
use Bio::SeqIO;

use base 'Mojolicious::Controller';

use version;
our $VERSION = qv('2.0.0');

sub write_sequence {
    my ($self) = @_;
    my $app = $self->app;

    my $id         = $self->req->param('id');
    my $type       = $self->req->param('type');
    my $organism   = $self->req->param('organism');
    my $connection = $self->get_model($organism);

    my $feature = $connection->resultset('Sequence::Feature')
        ->find( { 'dbxref.accession' => $id }, { join => 'dbxref' } );

    my ( $sequence, $header );
    if ( $organism eq 'discoideum' ) {
        $sequence = $self->get_sequence( $feature, $type );
        $header   = $self->get_header( $feature,   $type );
        if ( !$sequence ) {
            $self->render( text =>
                    "No sequence of type $type found for $id, please report to "
                    . $self->app->config->{blast}->{site_admin_email} );
            return;
        }
    }
    else {
        ( $header, $sequence )
            = $self->sequence_info_from_chado( $feature, $type );
        if ( !$sequence ) {
            $self->render( text =>
                    "No sequence of type $type found for $id, please report to "
                    . $self->app->config->{blast}->{site_admin_email} );
            return;
        }
    }
    $sequence =~ s/(\w{1,60})/$1\n/g;
    my $fasta = ">$header\n$sequence";
    $self->render( text => $fasta );
}

sub sequence_info_from_chado {
    my ( $self, $feature, $type ) = @_;

    # -- direct sequence retrieval no fallbacks at this point
    if ( $type =~ /Genomic/i ) {    #unspliced transcript sequence
        return ( $feature->dbxref->accession, $feature->residues );
    }
    elsif ( $type =~ /coding/i ) {
        my $exon_rs = $feature->search_related(
            'feature_relationship_objects',
            { 'type.name' => 'part_of' },
            { join        => 'type' }
            )->search_related(
            'subject',
            { 'type_2.name' => 'exon' },
            { join          => 'type' }
            )
            ->search_related( 'featureloc_features', {},
            { 'order_by' => { -asc => 'fmin' } } );

        my $seq;
        for my $erow ( $exon_rs->all ) {
            my $start  = $erow->fmin + 1;
            my $end    = $erow->fmax;
            my $seqlen = $end - $start + 1;
            $seq .= $erow->search_related(
                'srcfeature',
                {},
                {   select => [ \"SUBSTR(me.residues,  $start, $seqlen)" ],
                    as     => 'fseq'
                }
            )->first->get_column('fseq');
        }
        if ( $feature->featureloc_features->first->strand == -1 ) {
            $seq = join( '', reverse( split '', $seq ) );
            $seq =~ tr/ATGC/TACG/;
        }
        return ( $feature->dbxref->accession, $seq );
    }
    else {
        my $poly_rs = $feature->search_related(
            'feature_relationship_objects',
            { 'type.name' => 'part_of' },
            { join        => 'type' }
            )->search_related(
            'subject',
            { 'type_2.name' => 'polypeptide' },
            { join          => 'type' }
            );
        my $row = $poly_rs->first;
        return ($row->dbxref->accession, $row->residues);
    }
}

1;
