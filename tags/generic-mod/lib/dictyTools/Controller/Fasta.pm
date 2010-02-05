package dictyTools::Controller::Fasta;

use strict;
use warnings;
use Chado::AutoDBI;
use dicty::DBH;
use IO::String;
use Bio::SeqIO;
use base qw/Mojolicious::Controller/;

sub write_sequence {
    my ( $self, $c ) = @_;
    my $app = $self->app;

    my $id   = $self->req->param('id');
    my $type = $self->req->param('type');
    my $organism = $self->req->param('organism');
    
    if ( $organism && $organism eq 'discoideum' ) {
        my $dbh_class     = 'dicty::DBH';
        my $organism_conf = $app->config->{organism}->{discoideum};

        $dbh_class->sid( $organism_conf->{sid} );
        $dbh_class->host( $organism_conf->{host} );
        $dbh_class->user( $organism_conf->{user} );
        $dbh_class->password( $organism_conf->{password} );

        $self->get_sequence($id, $type);

        $dbh_class->reconnect(0);
        $dbh_class->reset_params();
    }
    else {
        $self->get_sequence($id, $type);
    }
}

sub get_sequence {
    my ($self, $id, $type) = @_;
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
