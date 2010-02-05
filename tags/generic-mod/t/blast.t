#!/usr/bin/env perl

use strict;
use warnings;

use Mojo::Client;
use Mojo::Transaction;
use Test::More tests => 5;

use_ok('dictyTools');

my $blast_url = '/tools/blast';
my $blast_programs_url = $blast_url . '/programs';
my $blast_databases_url = $blast_url . '/databases';
my $blast_run_url = $blast_url . '/run';
my $blast_report_url = $blast_url . '/report';


# blast index page
my $client = Mojo::Client->new;
my $tx = Mojo::Transaction->new_get($blast_url);
$client->process_app( 'dictyTools', $tx );

SKIP: {
    #skip 'blast server is down', 4 if $client->app->is_connected;

    is( $tx->res->code, 200, "is a successful response for $blast_url" );
    is($tx->res->headers->content_type, 'text/html');
    like( $tx->res->body, qr/BLAST/i,
        'is the title for gene page' );
    like(
        $tx->res->body,
        qr/Supported by NIH/i,
        'is the common footer for every gene page'
    );
}

