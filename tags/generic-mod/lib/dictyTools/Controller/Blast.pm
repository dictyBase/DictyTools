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

use base qw/Mojolicious::Controller/;

sub index {
    my ( $self, $c ) = @_;
    my $app = $self->app;

    my $id_search =
        $app->config->{blast}->{id_search}
        && ( $app->config->{blast}->{id_search} ne 'enabled' )
        ? 1
        : 0;

    $self->render(
        template   => $app->config->{blast}->{template},
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
    my ( $self, $c ) = @_;
    my $app = $self->app;
    $self->render( handler => 'json', data => $app->programs );
}

sub databases {
    my ( $self, $c ) = @_;
    my $app = $self->app;
    $self->render( handler => 'json', data => $app->databases );
}

sub run {
    my ( $self, $c ) = @_;
    my $app = $self->app;

    my $program  = $self->req->param('program');
    my $database = $self->req->param('database');
    my $evalue   = $self->req->param('evalue');
    my $matrix   = $self->req->param('matrix');
    my $filter   = $self->req->param('filter');
    my $gapped   = $self->req->param('gapped');
    my $limit    = $self->req->param('limit');
    my $sequence = $self->req->param('sequence');

    if ( !( $program && $database && $sequence && $matrix ) ) {
        $c->res->code(404);
        $self->render(
            template => $app->config->{page}->{error},
            message => "program, database, sequence, matrix must be defined ",
            error   => 1,
            header  => 'Error page',
        );
        return;
    }
    my %options = (
        p => $program,
        d => $database,
        M => $matrix,
        i => $sequence
    );

    $options{e} = $evalue if $evalue;
    $options{F} = $filter if $filter;
    $options{g} = $gapped if $gapped;
    $options{b} = $limit  if $limit;
    $options{v} = $limit  if $limit;

    my $report = $app->server->blastall(%options);
    if ( $report->fault || $report->result =~ m{sorry}i || $report->result !~ m{BLAST}) {
        my $email =
        '<a href="mailto:'
        . $app->config->{blast}->{site_admin_email} . '">'
        . $app->config->{blast}->{site_admin_email} . '</a>';
        
        $app->log->info($report->faultstring) if $report->fault;
        
        my $message = "Sorry, an error occurred on our server. This is usually due to the BLAST report being too large. You can try reducing the number of alignments to show, increasing the E value and/or leaving the gapped alignment to 'True' and filtering 'On'. If you still get an error, please email $email with the sequence you were using for the BLAST and the alignment parameters.";
        
        $self->res->headers->content_type('text/plain');
        $self->res->body($message);
        return;
    }

    my $tmp = File::Temp->new( DIR => $self->app->home->rel_dir('public').'/tmp/dictytools/', UNLINK => 0);
    my $filename = $tmp->filename;

    $tmp->print($report->result);
    $tmp->close;
    
    $self->res->headers->content_type('text/plain');
    $self->res->body( $filename );
}

sub report {
    my ( $self, $c ) = @_;
    my $app = $self->app;
    
    my $html_hash = $app->helper->blast_report($self->req->param('report_file'),  $c);
    my $graph     = $app->helper->blast_graph($self->req->param('report_file'));
    
    $self->render(
        template   => $self->app->config->{blast}->{report_template},
        graph      => $graph,
        top        => $html_hash->{top},
        table      => $html_hash->{table},
        results    => $html_hash->{results},
        parameters => $html_hash->{parameters},
        statistics => $html_hash->{statistics},
        logo_link  => $app->config->{page}->{logo_link} || "/",
    );
    unlink $self->req->param('report_file');
}

1;
