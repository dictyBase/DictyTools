#!perl

use strict;
use warnings;
use Test::More qw/no_plan/;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Test::Mojo;
use dicty::Search::Gene;

use_ok 'dictyTools';

my $t = Test::Mojo->new( app => 'dictyTools' );

my $name = 'test_CURATED';
my ($gene) = dicty::Search::Gene->find(
    -name       => $name,
    -is_deleted => 'false'
);
SKIP: {
    skip "test data ($name gene) has to be inserted to proceed", 11
        unless $gene;

    my $gene_id       = $gene->primary_id;
    my ($transcript)  = @{ $gene->transcripts };
    my $transcript_id = $transcript->primary_id();
    my $protein_seq =
        $transcript->sequence( -type => 'Protein', -format => 'fasta' );

    $t->post_ok(
        '/tools/fasta?type=Protein&organism=purpureum&id=' . $transcript_id )
        ->status_is( 200, 'successful response for FASTA retrivial' )
        ->content_type_like( qr/text/, 'text response for FASTA retrivial' )
        ->content_like( qr/Protein/i,      'got protein sequence' )
        ->content_like( qr/$protein_seq/i, 'protein sequence matches' );
};