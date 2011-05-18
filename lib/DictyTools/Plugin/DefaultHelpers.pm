package DictyTools::Plugin::DefaultHelpers;

use strict;
use Bio::PrimarySeq;
use Bio::SeqFeature::Gene::Exon;
use Bio::SeqFeature::Generic;
use base 'Mojolicious::Plugin';

sub register {
    my ( $self, $app ) = @_;
    $app->helper(
        subfeatures => sub {
            my ( $c, $feature ) = @_;
            return $feature->search_related('feature_relationship_objects')
                ->search_related( 'subject', { is_deleted => 0 } );
        }
    );
    $app->helper(
        get_featureprop => sub {
            my ( $c, $feature, $prop ) = @_;
            return map { $_->value }
                grep { $_->type->name eq $prop } $feature->featureprops;
        }
    );
    $app->helper(
        get_sequence => sub {
            my ( $c, $feature, $type ) = @_;

            my ($sequence) = $c->get_featureprop( $feature, $type );
            return $sequence if $sequence;

            $self->add_bioperl($feature);
            $type =~ s{\s}{_}g;
            my $methodname = "calculate_" . lc($type);
            return $self->$methodname($feature);
        }
    );
    $app->helper(
        get_header => sub {
            my ( $c, $feature, $type ) = @_;

            my $feat_location = $feature->featureloc_features->first;
            my $ref_feat =
                $feat_location ? $feat_location->srcfeature : undef;

            my ($gene) =
                $feature->search_related('feature_relationship_subjects')
                ->search_related('object');

            my $header;
            $header .= "|" . $gene->dbxref->accession
                if $gene;
            $header .= "|" . $type . "|";
            $header .= " gene: " . $gene->uniquename if $gene;
            $header .= " on " . $ref_feat->type->name . ": " . $ref_feat->name
                if $ref_feat;
            $header .=
                  " position "
                . ( $feat_location->fmin + 1 ) . " to "
                . $feat_location->fmax
                if $ref_feat;

            if ( $type =~ m{Genomic}i ) {
                $self->add_bioperl($feature);
                my $flank_up =
                    $feature->{bioperl}->start > 1000
                    ? 1000
                    : $feature->{bioperl}->start - 1;
                my $flank_down =
                    ( $feature->{bioperl}->entire_seq->length ) -
                    $feature->{bioperl}->end > 1000
                    ? 1000
                    : ( $feature->{bioperl}->entire_seq->length ) -
                    $feature->{bioperl}->end;

                $header .= " plus ";
                $header .=
                      $feature->{bioperl}->strand ne "-1"
                    ? $flank_up
                    : $flank_down;
                $header .= " upstream and ";
                $header .=
                      $feature->{bioperl}->strand ne "-1"
                    ? $flank_down
                    : $flank_up;
                $header .= " downstream basepairs";
                $header .= ", reverse complement"
                    if ( $feature->{bioperl}->strand eq '-1' );
            }
            return $header;
        }
    );
}

sub add_bioperl {
    my ( $self, $feature ) = @_;

    my $feat_location = $feature->featureloc_features->first;
    my $strand        = $feat_location->strand;

    my $exon_rs =
        $feature->search_related('feature_relationship_objects')
        ->search_related( 'subject', { is_deleted => 0 } )
        ->search( { 'type.name' => 'exon' }, { join => 'type' } );

    my @exons;
    foreach my $exon_feat ( $exon_rs->all ) {
        my $location = $exon_feat->featureloc_features->first;

        # chado is interbase coordinates, so add 1 to start of exons
        my $exon = Bio::SeqFeature::Gene::Exon->new(
            -start  => $location->fmin + 1,
            -end    => $location->fmax,
            -strand => $location->strand
        );
        push @exons, $exon;
    }

    # sort the exons by start ( order is reversed based on strand )
    @exons = map { $_->[1] }
        sort { $strand * $a->[0] <=> $strand * $b->[0] }
        map { [ $_->start, $_ ] } @exons;

    my $bioperl = Bio::SeqFeature::Generic->new(
        -strand => $strand,
        -start  => $feat_location->fmin + 1,
        -end    => $feat_location->fmax,
    );

    # and add them to bioperl object
    map { $bioperl->add_SeqFeature($_) } @exons;

    # attach reference feature sequence if exists
    my $ref_feat = $feat_location->srcfeature;
    my $ref_seq  = Bio::PrimarySeq->new(
        -primary_id => $ref_feat->feature_id,
        -seq        => $ref_feat->residues,
    );
    my $ref_bioperl =
        Bio::Seq->new( -primary_id => $ref_feat->dbxref->accession );
    $ref_bioperl->primary_seq($ref_seq);

    $bioperl->attach_seq($ref_bioperl);
    $feature->{bioperl} = $bioperl;

    return;
}

sub calculate_spliced_transcript {
    my ( $self, $feature ) = @_;
    my $seq;

    my @exons = $feature->{bioperl}->get_SeqFeatures();
    map { $seq = $seq . $_->seq->seq() } @exons;
    return $seq;
}

sub calculate_dna_coding_sequence {
    my ( $self, $feature ) = @_;
    return $self->calculate_spliced_transcript($feature);
}

sub calculate_genomic {
    my ( $self, $feature ) = @_;

    my ( $genomic_start, $genomic_end, $flank_up, $flank_down );

    if ( $feature->{bioperl}->start() > 1000 ) {
        $genomic_start = $feature->{bioperl}->start() - 1000;
        $flank_up      = 1000;
    }
    else {
        $genomic_start = 1;
        $flank_up      = $feature->{bioperl}->start() - 1;
    }

    if ( ( $feature->{bioperl}->entire_seq->length ) -
        $feature->{bioperl}->end() > 1000 ) {
        $genomic_end = $feature->{bioperl}->end() + 1000;
        $flank_down  = 1000;
    }
    else {
        $genomic_end = ( $feature->{bioperl}->entire_seq->length );
        $flank_down =
            ( $feature->{bioperl}->entire_seq->length ) -
            $feature->{bioperl}->end();
    }

    my $seq =
          $feature->{bioperl}->strand ne "-1"
        ? $feature->{bioperl}
        ->entire_seq->trunc( $genomic_start, $genomic_end )
        : $feature->{bioperl}
        ->entire_seq->trunc( $genomic_start, $genomic_end )->revcom;
    return $seq->seq;
}

sub calculate_genomic_dna {
    my ( $self, $feature ) = @_;
    return $self->calculate_genomic($feature);
}

sub calculate_pseudogene {
    my ( $self, $feature ) = @_;
    return $feature->{bioperl}->seq->seq;
}

sub calculate_protein {
    my ( $self, $feature ) = @_;

    return $feature->search_related(
        'feature_relationship_objects',
        { 'type.name' => 'derived_from' },
        { join        => 'type' }
    )->search_related('subject')->first->residues;
}

1;
