#!/usr/bin/perl

use strict;
use local::lib '/home/ubuntu/dictyBase/Libs/mojo';
use File::Basename 'dirname';
use File::Spec;

use lib join '/', File::Spec->splitdir(dirname(__FILE__)), 'lib';
use lib join '/', File::Spec->splitdir(dirname(__FILE__)), '..', 'lib';

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../lib";


use Mojo::Server::PSGI;

BEGIN {
    $ENV{MOJO_MODE} = 'development';
}

print "$FindBin::Bin/../lib"."\n";
print "$FindBin::Bin/../../lib"."\n";
print join '/', File::Spec->splitdir(dirname(__FILE__)), 'lib';
print "\n";
print join '/', File::Spec->splitdir(dirname(__FILE__)), '..', 'lib';
print "\n";

my $psgi = Mojo::Server::PSGI->new( app_class => 'dictyTools' );
my $app = sub { $psgi->run(@_) };
$app;

