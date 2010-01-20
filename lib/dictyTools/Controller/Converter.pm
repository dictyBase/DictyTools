package dictyTools::Controller::Converter;

use strict;
use warnings;
use Chado::AutoDBI;
use dicty::DBH;
use IO::String;
use base qw/Mojolicious::Controller/;

sub index { }

sub convert {
    my ( $self, $c ) = @_;
    my $app = $self->app;

    my $from     = $self->req->param('from');
    my $to       = $self->req->param('to');
    my $ids      = $self->req->param('ids');
    my $organism = $self->req->param('organism');

    my $method = $from . '2' . $to;

    if ( $organism && $organism eq 'discoideum' ) {
        my $dbh_class     = 'dicty::DBH';
        my $organism_conf = $app->config->{organism}->{discoideum};

        $dbh_class->sid( $organism_conf->{sid} );
        $dbh_class->host( $organism_conf->{host} );
        $dbh_class->user( $organism_conf->{user} );
        $dbh_class->password( $organism_conf->{password} );

        $self->$method($ids);

        $dbh_class->reconnect(0);
        $dbh_class->reset_params();
    }
    else {
        $self->$method($ids);
    }
}

sub gene2features {
    my ( $self, $id ) = @_;

    ## -- get gene by id
    my ($dbxref) = Chado::Dbxref->search( accession => $id );
    my ($gene) = Chado::Feature->search( dbxref_id => $dbxref->id );

    return 'ID not recognized' if !$gene;
    return 'Gene was deleted'  if $gene->is_deleted;

    ## -- get primary and genbank features
    my @primary = $self->primary_features($gene);
    my @genbank = $self->genbank_features($gene);

    ## make an array of hashes containing id of the feature and its descriptor
    my @array;
    push @array, map {
        {   id => Chado::Dbxref->get_single_row( dbxref_id => $_->dbxref_id )
                ->accession,
            description => $self->description($_)
        }
    } ( @primary, @genbank );

    $self->render( handler => 'json', data => \@array );
}

sub description {
    my ( $self, $feature ) = @_;
    my $type = Chado::Cvterm->get_single_row( cvterm_id => $_->type )->name;
    return 'Curated Gene Model'       if $feature->{curated};
    return 'Predicted Gene Model'     if $type eq 'mRNA';
    return 'GenBank Genomic Fragment' if $type =~ m{databank}i;
    return 'GenBank mRNA'             if $type =~ m{cdna}i;
    return $type;
}

sub primary_features {
    my ( $self, $gene ) = @_;

    ## -- get all gene features
    my @features = @{ $self->app->helper->subfeatures($gene) };

    ## -- filter out cds, trna, ncrna and pseudogenes
    my @cdss = grep {
        Chado::Cvterm->get_single_row( cvterm_id => $_->type )->name eq "mRNA"
    } @features;

    my @trna = grep {
        Chado::Cvterm->get_single_row( cvterm_id => $_->type )->name eq "tRNA"
    } @features;

    my @ncrna = grep {
        Chado::Cvterm->get_single_row( cvterm_id => $_->type )->name =~
            m{[^mt]RNA}
    } @features;

    my @pseudogene = grep {
        Chado::Cvterm->get_single_row( cvterm_id => $_->type )->name eq
            "pseudogene"
    } @features;

    ## -- get curated and predicted features
    my @curated;
    my @predicted;
    foreach my $feature (@cdss) {
        my @curated_source =
            grep { $_->accession =~ m{curator}i }
            map { Chado::Dbxref->search( dbxref_id => $_->dbxref_id ) }
            Chado::Feature_Dbxref->search(
            feature_id => $feature->feature_id );

        $feature->{curated} = 1 if @curated_source;

        push @curated,   $feature if @curated_source;
        push @predicted, $feature if !@curated_source;
    }

    return @pseudogene if @pseudogene;
    return @ncrna      if @ncrna;
    return @trna       if @trna;
    return @curated    if @curated;
    return @predicted  if @predicted;
    return;
}

sub genbank_features {
    my ( $self, $gene ) = @_;
    my $source_db = Chado::Db->get_single_row( name => 'GFF_source' );

    my @features = @{ $self->app->helper->subfeatures($gene) };
    my @genbank;
    foreach my $feature (@features) {
        push @genbank, $feature
            if grep { $_->accession =~ m{GenBank}ix }
                map { Chado::Dbxref->search( dbxref_id => $_->dbxref_id ) }
                Chado::Feature_Dbxref->search(
                    feature_id => $feature->feature_id
                );
    }

    my @genbank_cdna = grep {
        Chado::Cvterm->get_single_row( cvterm_id => $_->type )->name =~
            m{databank}i
    } @genbank;

    my @genbank_mrna = grep {
        Chado::Cvterm->get_single_row( cvterm_id => $_->type )->name =~
            m{cdna}i
    } @genbank;
    return ( @genbank_cdna, @genbank_mrna );
}

sub feature2seqtypes {
    my ( $self, $id ) = @_;
    my ($dbxref) = Chado::Dbxref->search( accession => $id );
    my ($feature) = Chado::Feature->search( dbxref_id => $dbxref->id );

    return 'ID not recognized'   if !$feature;
    return 'Feature was deleted' if $feature->is_deleted;

    my $type =
        Chado::Cvterm->get_single_row( cvterm_id => $feature->type )->name;
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
            my $seq =
                $self->app->helper->get_featureprop( $feature, $seqtype );
            push @$sequences, $seqtype if $seq;
        }
    }
    elsif ( $type =~ m{databank_entry} ) {
        my @seqtypes = ( 'Protein', 'DNA coding sequence', 'Genomic DNA' );
        foreach my $seqtype (@seqtypes) {
            my $seq =
                   $self->app->helper->get_featureprop( $feature, $seqtype )
                || $self->app->helper->get_sequence( $feature, $seqtype );
            push @$sequences, $seqtype if $seq;
        }
    }
    $self->render( handler => 'json', data => $sequences );
}

1;
