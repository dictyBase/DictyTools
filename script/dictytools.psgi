#!/usr/bin/perl

use strict;
use FindBin;    ## don't ask me why
use File::Basename 'dirname';
use File::Spec;

use lib join '/', File::Spec->splitdir( dirname(__FILE__) ), '..', 'lib';

use Mojo::Server::PSGI;

BEGIN {
    $ENV{MOJO_MODE} = 'development';
}

my $psgi = Mojo::Server::PSGI->new( app_class => 'DictyTools' );
my $app = sub { $psgi->run(@_) };
$app;
