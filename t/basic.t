#!/usr/bin/env perl

use strict;
use warnings;

use Mojo::Client;
use Mojo::Transaction;
use Test::More tests => 5;

use_ok('dictyTools');

my $root_url = '/';
my $tools_url = '/tools';

# Prepare client and transaction
my $client = Mojo::Client->new;
my $tx     = Mojo::Transaction->new_get($root_url);

$client->process_app('dictyTools', $tx);

is( $tx->res->code, 404, 'resource does not exist' );
like( $tx->res->body, qr/File not found/i, 'is a generic error response' );

$tx     = Mojo::Transaction->new_get($tools_url);
$client->process_app('dictyTools', $tx);

is( $tx->res->code, 404, 'resource does not exist' );
like( $tx->res->body, qr/File not found/i, 'is a generic error response' );