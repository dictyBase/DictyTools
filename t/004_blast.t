#!perl

use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Test::Mojo;
use dicty::Search::Gene;
use SOAP::Lite;
use YAML;

my $conf_file = "$FindBin::Bin/../conf/" . $ENV{MODE} . ".yaml";
plan skip_all =>
    "could not find config file ($conf_file) with blast server settings"
    if !-e $conf_file;

my $config = YAML::LoadFile($conf_file);

my $blast_server =
    SOAP::Lite->ns( $config->{blast}->{namespace} )
    ->proxy( $config->{blast}->{proxy} );

my ( $programs, $databases );
eval { ( $programs, $databases ) = @{ $blast_server->config->result } };

plan skip_all => 'Could not connect to ' . $config->{blast}->{proxy} if $@;
plan qw/no_plan/;

use_ok 'DictyTools';

my $t = Test::Mojo->new( app => 'DictyTools' );

$t->get_ok('/tools/blast/')
    ->status_is( 200, 'successful response for BLAST main form' )
    ->content_type_like( qr/html/, 'html responce for BLAST main form' )
    ->content_like( qr/Enter query sequence in FASTA format/i, 'got form' );

$t->get_ok('/tools/blast/programs')
    ->status_is( 200, 'successful response for BLAST programs retrivial' )
    ->content_type_like( qr/json/, 'json responce for BLAST programs' )
    ->content_like( qr/blastn/i, 'got blastn in list' )
    ->content_like( qr/blastp/i, 'got blastp in list' );

$t->get_ok('/tools/blast/databases')
    ->status_is( 200, 'successful response for BLAST databases retrivial' )
    ->content_type_like( qr/json/, 'json responce for BLAST databases' )
    ->content_like( qr/discoideum/i, 'got discoideum in list' )
    ->content_like( qr/protein/i,    'got protein in list' );

my $name = 'test_CURATED';
my ($gene) = dicty::Search::Gene->find(
    -name       => $name,
    -is_deleted => 'false'
);
SKIP: {
    skip "test data ($name gene) has to be inserted to proceed", 11
        unless defined $gene;

    my $gene_id       = $gene->primary_id;

    my ($transcript)  = @{ $gene->transcripts };
    my $transcript_id = $transcript->primary_id();
    my $protein_seq =
        $transcript->sequence( -type => 'Protein', -format => 'fasta' );

    my $options = {
        program  => 'blastp',
        database => 'dicty_primary_protein',
        matrix   => 'BLOSUM62',
        sequence => $protein_seq,
        evalue   => '1.0e-10',
        filter   => 'T',
        gapped   => 'F',
        limit    => 1,
    };

    $t->post_form_ok( '/tools/blast/run/', '', $options,
        { 'Content-Type' => 'multipart/form-data' } )
        ->status_is( 200, 'successful response for BLAST run' )
        ->content_type_like( qr/text/, 'text responce for BLAST run' )
        ->content_like( qr/^\w+$/i, 'got some text' );

    my $tmp_file = $t->tx->res->body;

    $t->get_ok( '/tools/blast/report/'.$tmp_file)
        ->status_is( 200, 'successful response for BLAST report' )
        ->content_type_like( qr/html/, 'html responce for BLAST report' )
        ->content_like( qr/BLAST report/i, 'got BLAST report header' )
        ->content_like( qr/BLASTP/i, 'it is BLASTP report' )
        ->content_like( qr/Sequences producing significant alignments/i, 'got some sequences aligned' )
        ->content_like( qr/$transcript_id/i, 'got proper id in list' );
};
