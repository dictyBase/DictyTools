#!/usr/bin/perl

use strict;
#use local::lib '/home/ubuntu/dictyBase/Libs/mojo';
use FindBin;
use Mojo::Server::FastCGI;

use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../lib";
use lib '/home/ubuntu/dicty/lib';

BEGIN {
    $ENV{MOJO_MODE} = 'development';
}

my $fcgi = Mojo::Server::FastCGI->new( app_class => 'dictyTools' );
$fcgi->run;

