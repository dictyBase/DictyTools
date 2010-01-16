package dictyTools::Controller::Fasta;

use strict;
use warnings;
use Chado::AutoDBI;
use dicty::DBH;
use Data::Dumper;
use IO::String;
use Bio::SeqIO;
use base qw/Mojolicious::Controller/;

sub get_sequence {
    my ( $self, $c ) = @_;
    my $app = $self->app;

    my $id   = $self->req->param('id');
    my $type = $self->req->param('type');

    my ($dbxref) = Chado::Dbxref->search( accession => $id );
    my ($feature) = Chado::Feature->search( dbxref_id => $dbxref->id );

    my ($gene) =
        map { Chado::Feature->get_single_row( feature_id => $_->id ) }
        map { $_->object_id }
        Chado::Feature_Relationship->search( subject_id => $feature->id );

    my $sequence = $self->app->helper->get_featureprop( $feature, $type )
        || $self->app->helper->get_sequence( $feature, $type );

    if ( !$sequence ) {
        $self->res->headers->content_type('text/plain');
        $self->res->body(
            "No sequence of type $type found for $id, please report to "
                . $self->app->config->{blast}->{site_admin_email} );
        return;
    }

    my $header;
    $header .= "|"
        . Chado::Dbxref->get_single_row( dbxref_id => $gene->dbxref_id )
        ->accession
        if $gene;
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
    $self->res->headers->content_type('text/plain');
    $self->res->body( ${ $str->string_ref } );

}

1;
