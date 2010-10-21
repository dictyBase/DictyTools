package dictyTools::Controller::Blast;

use strict;
use warnings;
use IO::String;
use File::Temp;
use Bio::SearchIO;
use Bio::SearchIO::Writer::HTMLResultWriter;
use Bio::Graphics;
use Bio::SeqFeature::Generic;
use File::Spec::Functions;

use base 'Mojolicious::Controller';

use version; 
our $VERSION = qv('2.0.0');

sub index {
    my ($self) = @_;
    my $app = $self->app;

    my $id_search =
        $app->config->{blast}->{id_search}
        && ( $app->config->{blast}->{id_search} ne 'enabled' )
        ? 1
        : 0;

    $self->render(
        template   => 'blast/index',
        primary_id => $self->req->param('primary_id') || undef,
        sequence   => $self->req->param('sequence') || undef,
        no_header  => $self->req->param('noheader') || undef,
        logo_link  => $app->config->{page}->{logo_link} || "/",
        id_search  => $id_search,
        database_download_url =>
            $app->config->{blast}->{database_download_url} || undef
    );
}

sub programs {
    my ($self) = @_;
    my $app = $self->app;
    $self->render( json => $app->programs );
}

sub databases {
    my ($self) = @_;
    my $app = $self->app;
    $self->render( json => $app->databases );
}

sub run {
    my ($self) = @_;
    my $app = $self->app;
    
#    $self->stash('mojo.rendered' => 1);
#    my $body = $self->res->body || '';
#    $self->res->body("called, $body");

    my $program = $self->req->param('program');
    my $database = $self->req->param('database');
    my $sequence = $self->req->param('sequence');
    my $matrix = $self->req->param('matrix');
    
    if ( !( $program && $database && $sequence && $matrix ) ) {
        my $message = 'program, database, sequence and matrix must be defined';
        $app->log->error($message);
        $self->render( text => $message, 500 );
        return;
    }

    my %options = (
        p => $program,
        d => $database,
        M => $matrix,
        i => $sequence
    );

    $options{e} = $self->req->param('evalue');
    $options{F} = $self->req->param('filter');
    $options{g} = $self->req->param('gapped');
    $options{b} = $self->req->param('limit');
    $options{v} = $self->req->param('limit');

    my $report = $app->server->blastall(%options);

    ## catch fault string
    if (   $report->fault
        || $report->result =~ m{sorry}i
        || $report->result !~ m{BLAST} ) {
        my $email =
              '<a href="mailto:'
            . $app->config->{blast}->{site_admin_email} . '">'
            . $app->config->{blast}->{site_admin_email} . '</a>';

        $app->log->info( $report->faultstring ) if $report->fault;

        my $message =
            "Sorry, an error occurred on our server. This is usually due to the BLAST report being too large. You can try reducing the number of alignments to show, increasing the E value and/or leaving the gapped alignment to 'True' and filtering 'On'. If you still get an error, please email $email with the sequence you were using for the BLAST and the alignment parameters.";
        $self->render( text => $message, status => 500 );
        return;
    }

    ## write report to teporary file, return tmp file name
    my $dir =
          $self->app->home->rel_dir('public')
        . $self->app->config->{blast}->{tmp_folder};

    my $tmp = File::Temp->new( DIR => $dir, UNLINK => 0 );
    $tmp->print( $report->result );
    $tmp->close;

    my $filename = $tmp->filename;
    $filename =~ s{$dir}{};
    
    $self->render( text => $filename );
}

sub report {
    my ( $self, $c ) = @_;
    my $app = $self->app;

    my $file = $self->stash('id') || $self->req->param('report_file');

    if ( !$file ) {
        $self->redirect_to('/tools/blast');
        return;
    }
    my $dir =
          $self->app->home->rel_dir('public')
        . $self->app->config->{blast}->{tmp_folder};

    my $html_hash = $app->util->blast_report( catfile( $dir, $file ),
        $self->url_for->base );
    my $graph = $app->util->blast_graph( catfile( $dir, $file ) );

    $self->render(
        template   => $self->app->config->{blast}->{report_template},
        graph      => $graph,
        top        => $html_hash->{top},
        table      => $html_hash->{table},
        results    => $html_hash->{results},
        parameters => $html_hash->{parameters},
        statistics => $html_hash->{statistics},
        logo_link  => $app->config->{page}->{logo_link} || "/",
        no_header  => $self->req->param('noheader') || undef,
        
    );

    #unlink catfile($dir, $file);
}

1;

