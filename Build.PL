#!/usr/bin/perl -w
use strict;
use warnings;
use lib 'lib';
use DictyTools::Builder;

my $builder = DictyToolsBuilder->new(
    module_name  => 'DictyTools',
    license      => 'perl',
    dist_author  => 'Yulia Bushmanova <y-bushmanova@northwestern.edu>',
    dist_version => '2.0.0',
    requires     => {
        'Mojolicious'   => '0.999938',
        'File::Spec::Functions' => '',
        'SOAP::Lite' => '',
        'YAML' => '',
        'IO::String' => '',
        'Bio::Perl' => '',
        'Bio::Graphics' => '', 
        'SQL::Abstract' => '1.63',
        'DBIx::Class' => '0.08120',
        'File::Path' => '2.04',
        'Bio::Chado::Schema' => '',
        'Bio::Graphics' => '2.14'    
    },
    build_requires => {
    	 'Archive::Extract' => '',
		},
    add_to_cleanup => ['DictyTools-*'],
    create_readme  => 1,
);

$builder->create_build_script();

1;
