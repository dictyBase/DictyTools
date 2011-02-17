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
    skip "test data ($name gene) has to be inserted to proceed", 8
        unless $gene;

    my $gene_id       = $gene->primary_id;
    my ($transcript)  = @{ $gene->transcripts };
    my $transcript_id = $transcript->primary_id();

    $t->post_ok( '/tools/converter?from=gene&to=features&organism=purpureum&ids='
            . $gene_id )
        ->status_is( 200, 'successful response for gene2features conversion' )
        ->content_type_like( qr/json/,
        'json response for gene2features conversion' )
        ->content_like( qr/$transcript_id/i, 'got correct transcript id' );

    $t->post_ok(
        '/tools/converter?from=feature&to=seqtypes&organism=purpureum&ids='
            . $transcript_id )
        ->status_is( 200, 'successful response for feature2seqtypes conversion' )
        ->content_type_like( qr/json/,
        'json response for feature2seqtypes conversion' )
        ->content_like( qr/Protein/i, 'got protein among sequence types' );
};