#!/usr/bin/perl -w
use strict;
use warnings;
use lib 'lib';
use DictyTools::Builder;

my $builder = DictyTools::Builder->new(
    module_name  => 'DictyTools',
    license      => 'perl',
    dist_author  => 'Yulia Bushmanova <y-bushmanova@northwestern.edu>',
    dist_version => '2.0.0',
    requires     => {
        'Mojolicious'                 => '0.999938',
        'Plack'                       => '0.9941',
        'FCGI::Engine'                => '0.16',
        'Mojolicious::Plugin::Bundle' => '0.001',
        'SOAP::Lite'                  => '',
        'IO::String'                  => '',
        'Bio::Perl'                   => '',
        'File::Path'                  => '2.04',
        'Bio::Chado::Schema'          => '',
        'Bio::Graphics'               => ''
    },
    build_requires => { 'Archive::Extract' => '', },
    add_to_cleanup => ['DictyTools-*'],
    create_readme  => 1,
);

$builder->create_build_script();

1;
