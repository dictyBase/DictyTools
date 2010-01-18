package dictyTools::Controller::Fasta;

use strict;
use warnings;
use Chado::AutoDBI;
use dicty::DBH;
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

    my $sequence = $self->app->helper->get_sequence( $feature, $type );
    my $header = $self->app->helper->get_header( $feature, $type );

    if ( !$sequence ) {
        $self->res->headers->content_type('text/plain');
        $self->res->body(
            "No sequence of type $type found for $id, please report to "
                . $self->app->config->{blast}->{site_admin_email} );
        return;
    }
    my $str = IO::String->new;
    eval {
        my $seqobj = Bio::Seq->new(
            -display_id => $id,
            -desc       => $header,
            -seq        => $sequence
        );

        my $out = Bio::SeqIO->new( -format => 'fasta', -fh => $str );
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
