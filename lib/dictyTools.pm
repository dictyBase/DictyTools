package dictyTools;

use strict;
use warnings;
use File::Spec::Functions;
use dictyTools::Util;
use Bio::Chado::Schema;
use SOAP::Lite +trace => 'all';

use YAML;
use Carp;
use base 'Mojolicious';

use version; 
our $VERSION = qv('2.0.0');

__PACKAGE__->attr('util');
__PACKAGE__->attr('config');
__PACKAGE__->attr('has_config');
__PACKAGE__->attr('server');
__PACKAGE__->attr('programs');
__PACKAGE__->attr('databases');
__PACKAGE__->attr('is_connected');
__PACKAGE__->attr('model');

# This will run once at startup
sub startup {
    my ($self) = @_;

    #default log level
    $self->log->level('debug');
    my $router = $self->routes();

    #config file setup
    $self->set_config();

    #set up blast server connection
    $self->set_connection();

    #set helper
    $self->util( dictyTools::Helper->new() );
    $self->util->app($self);

    #routing setup
    my $base = $router->namespace();
    $router->namespace( $base . '::Controller' );

    ## -- Organism
    $router->route('tools/organism')
        ->to( controller => 'organism', action => 'index', format => 'json' );

    ## -- Converter
    $router->route('tools/converter')->to(
        controller => 'converter',
        action     => 'convert',
        format     => 'json'
    );

    ## -- Fasta
    $router->route('tools/fasta')->to(
        controller => 'fasta',
        action     => 'write_sequence',
        format     => 'text'
    );

    my $bridge = $router->bridge('tools/blast')->to(
        controller => 'validation',
        action     => 'connection'
    );

    ## -- BLAST
    $bridge->route('')
        ->to( controller => 'blast', action => 'index', format => 'html' );

    $bridge->route('programs')
        ->to( controller => 'blast', action => 'programs', format => 'json' );

    $bridge->route('databases')->to(
        controller => 'blast',
        action     => 'databases',
        format     => 'json'
    );

    $bridge->route('run')
        ->to( controller => 'blast', action => 'run', format => 'text' );

    $bridge->route('report/')
        ->to( controller => 'blast', action => 'report', format => 'html' );

    $bridge->route('report/:id')
        ->to( controller => 'blast', action => 'report', format => 'html' );

}

sub set_config {
    my ( $self, $c ) = @_;

    #set up config file usually look under conf folder
    #supports similar profile as log file

    my $folder = $self->home->rel_dir('conf');
    if ( !-e $folder ) {
        return;
    }

#now the file name,  default which is developmental mode resolves to <name>.conf. For
#test and production it will be <name>.test.conf and <name>.production.conf respectively.

    my $mode   = $self->mode();
    my $suffix = '.yml';
    if ( $mode eq 'production' or $mode eq 'staging' ) {
        $suffix = '.' . $mode . '.yml';
    }
    my $app_name = lc $self->home->app_class;

    #opendir my $conf, $folder or confess "cannot open folder $!:$folder";
    #my $file = catfile()
    #closedir $conf;

    my $file = catfile( $folder, $app_name . $suffix );
    $self->log->debug(qq/got config file $file/);
    $self->config( YAML::LoadFile($file) );
    $self->has_config(1);

}

sub set_connection {
    my ($self) = @_;

    ## uses config values to connect to blast server. If connection was successful,
    ## sets is_connected attribute to 1 and saves connection object in server,
    ## stores available databases and programs in corresponding attributes. If connection fails
    ## is_connected parameter remains in default 0 value

    my $blast_server =
        SOAP::Lite->ns( $self->config->{blast}->{namespace} )
        ->proxy( $self->config->{blast}->{proxy} );

    my ( $programs, $databases );

    eval { ( $programs, $databases ) = @{ $blast_server->config->result } };
    if ($@) {
        $self->log->warn(
            "Could not establish connection to BLAST server: $@");
        return;
    }

    #@$databases = grep {$_->{private} && $_->{private} ne 1 } @$databases;
    $self->server($blast_server);
    $self->programs($programs);
    $self->databases($databases);

    $self->is_connected(1);
}

sub set_db_connection {
    my ($self) = @_;
    my $connection_hash;

    foreach my $organism ( keys %{ $self->config->{organism} } ) {
        my $organism_conf = $self->config->{organism}->{$organism};
        next if !$organism_conf->{dsn};

        my $connection = Bio::Chado::Schema->connect(
            $organism_conf->{dsn}, $organism_conf->{user},
            $organism_conf->{password}, { LongReadLen => 2**25 }
        );
        my $source = $connection->source('Sequence::Feature');
        $source->add_column(
            is_deleted => {
                data_type     => 'boolean',
                default_value => 'false',
                is_nullable   => 0,
                size          => 1
            }
        );
        $connection_hash->{$organism} = $connection;
    }
    $self->model($connection_hash) if $connection_hash;
}

1;

__END__

=head1 NAME

dictyTools - Web Framework

=head1 SYNOPSIS

    use base 'dictyTools';

    sub startup {
        my $self = shift;

        my $r = $self->routes;

        $r->route('/:controller/:action')
          ->to(controller => 'foo', action => 'bar');
    }

=head1 DESCRIPTION

L<Mojolicous> is a web framework built upon L<Mojo>.

See L<Mojo::Manual::dictyTools> for user friendly documentation.

=head1 ATTRIBUTES

L<dictyTools> inherits all attributes from L<Mojo> and implements the
following new ones.

=head2 C<mode>

    my $mode = $mojo->mode;
    $mojo    = $mojo->mode('production');

Returns the current mode if called without arguments.
Returns the invocant if called with arguments.
Defaults to C<$ENV{MOJO_MODE}> or C<development>.

    my $mode = $mojo->mode;
    if ($mode =~ m/^dev/) {
        do_debug_output();
    }

=head2 C<routes>

    my $routes = $mojo->routes;
    $mojo      = $mojo->routes(dictyTools::Dispatcher->new);

=head2 C<static>

    my $static = $mojo->static;
    $mojo      = $mojo->static(MojoX::Dispatcher::Static->new);

=head2 C<types>

    my $types = $mojo->types;
    $mojo     = $mojo->types(MojoX::Types->new)

=head1 METHODS

L<dictyTools> inherits all methods from L<Mojo> and implements the following
new ones.

=head2 C<new>

    my $mojo = dictyTools->new;

Returns a new L<dictyTools> object.
This method will call the method C<${mode}_mode> if it exists.
(C<$mode> being the value of the attribute C<mode>).
For example in production mode, C<production_mode> will be called.

=head2 C<build_ctx>

    my $c = $mojo->build_ctx($tx);

=head2 C<dispatch>

    $mojo->dispatch($c);

=head2 C<handler>

    $tx = $mojo->handler($tx);

=head2 C<startup>

    $mojo->startup($tx);

=cut
