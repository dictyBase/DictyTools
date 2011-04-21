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

    my $feature =
        $connection->resultset('Sequence::Feature')
        ->find( { 'dbxref.accession' => $id }, { join => 'dbxref' } );

    my $sequence = $self->get_sequence( $feature, $type );
    my $header = $self->get_header( $feature, $type );

    if ( !$sequence ) {
        $self->render( text =>
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
    $self->render( text => ${ $str->string_ref } );
}

1;