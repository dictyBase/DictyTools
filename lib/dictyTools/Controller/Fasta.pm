package dictyTools::Controller::Fasta;

use strict;
use warnings;
use Chado::AutoDBI;
use dicty::DBH;
use Data::Dumper;
use IO::String;
use base qw/Mojolicious::Controller/;

sub get_sequence {
    my ( $self, $c ) = @_;
    my $app = $self->app;
    
    my $id     = $self->req->param('id');
    my $type     = $self->req->param('type');
    
    my ($dbxref)  = Chado::Dbxref->search( accession => $id );
    my ($feature) = Chado::Feature->search( dbxref_id => $dbxref->id );
    
    my ($gene) = map {Chado::Feature->get_single_row( feature_id => $_->id ) }
        map { $_->object_id }
        Chado::Feature_Relationship->search( subject_id => $feature->id );

    my $sequence = $self->get_featureprop($feature, $type );
  
    my $header;
    $header .= "|" . Chado::Dbxref->get_single_row(dbxref_id => $gene->dbxref_id)->accession if $gene;
    $header .= "|" . $type . "|";
    $header .= " gene: " . $gene->uniquename if $gene;
    
    my $str = IO::String->new;
    my $seqobj;
    my $out;

    eval {
        $seqobj = Bio::Seq->new(
            -display_id => $id,
            -desc       => $header,
            -seq        => $sequence
        );

        $out = Bio::SeqIO->new( -format => 'fasta', -fh => $str );
        $out->write_seq($seqobj);
    };
    if ($@) {
        $self->app->log->debug( "Eror writing fasta sequence for "
                . $id . "\n"
                . "header: $header\n$@" );
    }
    $self->app->log->info(Dumper $str->string_ref);
#    $self->render( template=> 'plain', input => ${ $str->string_ref } );

    $self->res->headers->content_type('text/plain');
    $self->res->body(${ $str->string_ref });

}

sub get_featureprop {
    my ( $self, $feature, $prop ) = @_;
    my $type =
        Chado::Cvterm->get_single_row( cvterm_id => $feature->type )->name;

    my ($prop_term) = Chado::Cvterm->get_single_row(
        cv_id => Chado::Cv->get_single_row( name => 'autocreated' ),
        name  => $prop
    );

    ## -- give it another shot
    if ( !$prop_term ) {
        $prop_term = Chado::Cvterm->get_single_row(
            cv_id => Chado::Cv->get_single_row( name => 'sequence' ),
            name  => $prop,
        );
    }

    return undef if !$prop_term;

    my $prop_row = Chado::Featureprop->get_single_row(
        type_id    => $prop_term->cvterm_id,
        feature_id => $feature->feature_id
    );

    return $prop_row ? $prop_row->value() : undef;
}

1;
