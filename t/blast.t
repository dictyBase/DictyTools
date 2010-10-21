#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
plan tests => 8;

use Test::Mojo;
use Data::Dumper;
use Mojo::Asset::File;
use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok 'dictyTools';
my $t = Test::Mojo->new( app => 'dictyTools' );

$t->get_ok('/tools/blast')->status_is(200);
$t->get_ok('/tools/organism')->status_is(200);

my $file = Mojo::Asset::File->new->add_chunk('lalala');

$t->post_form_ok(
    '/tools/blast/run',
    {   database => 'dicty_primary_protein',
        evalue   => 0.1,
        filter   => 'T',
        gapped   => 'T',
        limit    => 50,
        matrix   => 'BLOSUM62',
        program  => 'blastp',
        file => {file => $file, filename => 'x'}
    }
)->status_is(200);