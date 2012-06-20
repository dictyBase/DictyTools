#!/usr/bin/perl -w
use strict;
use Module::Build;
use lib 'lib';

my $class = Module::Build->subclass(
    class => 'DictyToolsBuilder',
    code  => q{
       sub ACTION_create_temp_folders {
          use File::Path qw/make_path/;
          my ($self) = @_;
          make_path ('blast_output/results',  'blast_output/images',  {verbose => 1});
       }
    },
);

my $builder = $class->new(
    module_name  => 'DictyTools',
    license      => 'perl',
    dist_author  => 'Yulia Bushmanova <y-bushmanova@northwestern.edu>',
    dist_version => '2.0.0',
    requires     => {
        'Mojolicious'                 => '1.21',
        'Mojolicious::Plugin::Bundle' => '0.005',
        'SOAP::Lite'                  => '0.714',
        'Bio::Perl'                   => '1.0050021',
        'File::Path'                  => '2.04',
        'DBIx::Class'                 => '0.08127',
        'Math::BigInt'                => '1.99',
        'Math::Base36'                => '0.09',
        'DBI'                         => '1.51',
        'DBD::Oracle'                 => '1.27',
        'Bio::Chado::Schema'          => '0.058',
        'Bio::Graphics'               => '1.0050021'
    },
    add_to_cleanup => ['DictyTools-*'],
    create_readme  => 1,
);

$builder->create_build_script();

1;
