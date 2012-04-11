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
		($header, $sequence) = $self->get_sequence_info($feature, $type);
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

1;
