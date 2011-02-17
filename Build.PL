#!/usr/bin/perl -w
use strict;
use warnings;
use lib '.';
use dictyToolsBuilder;

my $builder = dictyToolsBuilder->new(
    module_name  => 'dictyTools',
    license      => 'perl',
    dist_author  => 'Yulia Bushmanova <y-bushmanova@northwestern.edu>',
    dist_version => '1.5.0',
    requires     => {
        'Mojolicious'   => '',
        'Apache2::Mojo' => '0.0047', 
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
    add_to_cleanup => ['dictyTools-*'],
    create_readme  => 1,
);

$builder->create_build_script();

1;
