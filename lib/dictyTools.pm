package dictyTools;

use strict;
use warnings;
use File::Spec::Functions;
use dictyTools::Renderer::JSON;
use dictyTools::Renderer::TT;
use dictyTools::Helper;
use SOAP::Lite;
use YAML;
use Carp;
use base 'Mojolicious';

__PACKAGE__->attr('helper');
__PACKAGE__->attr('config');
__PACKAGE__->attr( 'has_config', default => 0 );
__PACKAGE__->attr('template_path');
__PACKAGE__->attr('server');
__PACKAGE__->attr('programs');
__PACKAGE__->attr('databases');
__PACKAGE__->attr( 'is_connected', default => 0 );

# This will run once at startup
sub startup {
    my ($self) = @_;

    #default log level
    $self->log->level('debug');
    my $router = $self->routes();

    #config file setup
    $self->set_config();

    #set up various renderer
    $self->set_renderer();

    #set up blast server connection
    $self->set_connection();

    #set helper
    $self->helper( dictyTools::Helper->new() );
    $self->helper->app($self);

    #routing setup
    my $base = $router->namespace();
    $router->namespace( $base . '::Controller' );

    my $bridge = $router->bridge('/tools/blast')->to(
        controller => 'validation',
        action     => 'connection'
    );

    ## -- BLAST 
    $bridge->route('/')
        ->to( controller => 'blast', action => 'index', format => 'html' );

    $bridge->route('/programs')
        ->to( controller => 'blast', action => 'programs', format => 'json' );

    $bridge->route('/databases')->to(
        controller => 'blast',
        action     => 'databases',
        format     => 'json'
    );

    $bridge->route('/run')
        ->to( controller => 'blast', action => 'run', format => 'text' );

    $bridge->route('/report/')
        ->to( controller => 'blast', action => 'report', format => 'html' );

    $bridge->route('/report/:id')
        ->to( controller => 'blast', action => 'report', format => 'html' );

    ## -- Organism
    $router->route('/organism/')
        ->to( controller => 'organism', action => 'index', format => 'json' );
    
    ## -- Converter
    $router->route('/converter/')
        ->to( controller => 'converter', action => 'convert', format => 'json' );
    
    $router->route('/fasta/')
        ->to( controller => 'fasta', action => 'write_sequence', format => 'text' );
    
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
    if ( $mode eq 'production' or $mode eq 'test' ) {
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

sub set_renderer {
    my ($self) = @_;

    #try to set the default template path for TT
    #keep in mind this setup is separate from the Mojo's default template path
    #if something not specifically is not set it defaults to Mojo's default
    $self->template_path( $self->renderer->root );
    if ( $self->has_config and $self->config->{default}->{template_path} ) {
        $self->template_path( $self->config->{default}->{template_path} );
    }

    my $tpath = $self->template_path;

    $self->log->debug(qq/default template path for TT $tpath/);

    my $mode        = $self->mode();
    my $compile_dir = $self->home->rel_dir('tmp');
    if ( $mode eq 'production' or $mode eq 'test' ) {
        $compile_dir = $self->home->rel_dir('webtmp');
    }
    $self->log->debug(qq/default compile path for TT $compile_dir/);
    if ( !-e $compile_dir ) {
        $self->log->error("folder for template compilation is absent");
    }

    my $json = dictyTools::Renderer::JSON->new();
    my $tt   = dictyTools::Renderer::TT->new(
        path        => $self->template_path,
        compile_dir => $compile_dir,
        option      => {
            PRE_PROCESS  => $self->config->{page}->{header} || '',
            POST_PROCESS => $self->config->{page}->{footer} || '',
        },
    );
    
    $self->renderer->add_handler(
        tt   => $tt->build(),
        json => $json->build(),
    );
    $self->renderer->default_handler('tt');
}

sub set_connection {
    my ($self) = @_;

    ## uses config values to connect to blasr server. If connection was successful,
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

=head2 C<renderer>

    my $renderer = $mojo->renderer;
    $mojo        = $mojo->renderer(dictyTools::Renderer->new);

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
