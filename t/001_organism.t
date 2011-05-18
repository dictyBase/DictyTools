#!perl

use strict;
use warnings;
use Test::More qw/no_plan/;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Test::Mojo;
use dicty::Search::Gene;

use_ok 'DictyTools';

my $t = Test::Mojo->new( app => 'DictyTools' );

$t->get_ok('/tools/organism')
    ->status_is( 200, 'successful response for organism' )
    ->content_type_like( qr/json/, 'json response for organism' );



