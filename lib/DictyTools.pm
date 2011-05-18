package DictyTools;

use strict;
use base 'Mojolicious';
use version; 
our $VERSION = qv('2.0.0');

# This will run once at startup
sub startup {
    my ($self) = @_;

    $self->plugin('yml_config');
    $self->plugin('asset_tag_helpers');
    $self->plugin('DictyTools::Plugin::BLASTHelpers');
    $self->plugin('DictyTools::Plugin::DefaultHelpers');
    $self->plugin('DictyTools::Plugin::MultipleConnections');
    
    $self->defaults( "descriptor" => "New Universal Dictyostelid BLAST Server");

    my $router = $self->routes();
    my $base = $router->namespace();
    $router->namespace( $base . '::Controller' );

    ## -- Organism
    $router->route('/tools/organism')->to( 'organism#index', format => 'json' );

    ## -- Converter
    $router->route('/tools/converter')->to( 'converter#convert', format => 'json' );

    ## -- Fasta
    $router->route('/tools/fasta')->to( 'fasta#write_sequence', format => 'text' );

    ## -- BLAST server connection validation brige
    my $bridge = $router->bridge('/tools/blast')->to('validation#connection');

    ## -- BLAST
    $bridge->route('/')->to( 'blast#index', format => 'html' );
    $bridge->route('/programs')->to( 'blast#programs', format => 'json' );
    $bridge->route('/databases')->to( 'blast#databases', format => 'json' );
    $bridge->route('/run')->to( 'blast#run', format => 'text' );
    $bridge->route('/report')->to( 'blast#report', format => 'html' );
    $bridge->route('/report/:id')->to( 'blast#report', format => 'html' );
}

1;

__END__

=head1 NAME

DictyTools - Web Framework

=head1 SYNOPSIS

    use base 'DictyTools';

    sub startup {
        my $self = shift;

        my $r = $self->routes;

        $r->route('/:controller/:action')
          ->to(controller => 'foo', action => 'bar');
    }

=head1 DESCRIPTION

L<Mojolicous> is a web framework built upon L<Mojo>.

See L<Mojo::Manual::DictyTools> for user friendly documentation.

=head1 ATTRIBUTES

L<DictyTools> inherits all attributes from L<Mojo> and implements the
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
    $mojo      = $mojo->routes(DictyTools::Dispatcher->new);

=head2 C<static>

    my $static = $mojo->static;
    $mojo      = $mojo->static(MojoX::Dispatcher::Static->new);

=head2 C<types>

    my $types = $mojo->types;
    $mojo     = $mojo->types(MojoX::Types->new)

=head1 METHODS

L<DictyTools> inherits all methods from L<Mojo> and implements the following
new ones.

=head2 C<new>

    my $mojo = DictyTools->new;

Returns a new L<DictyTools> object.
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
