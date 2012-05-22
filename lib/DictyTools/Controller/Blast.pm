package DictyTools::Controller::Blast;

use strict;
use warnings;
use IO::String;
use File::Temp;
use Bio::SearchIO;
use Bio::SearchIO::Writer::HTMLResultWriter;
use Bio::Graphics;
use Bio::SeqFeature::Generic;
use File::Spec::Functions;
use File::Basename;

use base 'Mojolicious::Controller';

use version;
our $VERSION = qv('2.0.0');

sub index {
    my ($self) = @_;
    my $app = $self->app;

    my $id_search
        = $app->config->{blast}->{id_search}
        ? 1
        : 0;

    $self->render(
        template   => 'blast/index',
        title      => 'dictyBase BLAST Server',
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
    $self->render( json => $self->stash('programs') );
}

sub databases {
    my ($self) = @_;
    my $app = $self->app;
    $self->render( json => $self->stash('databases') );
}

sub run {
    my ($self) = @_;
    my $app = $self->app;

    my $program  = $self->req->param('program');
    my $database = $self->req->param('database');
    my $sequence = $self->req->param('sequence');
    my $matrix   = $self->req->param('matrix');

    if ( !( $program && $database && $sequence && $matrix ) ) {
        my $message
            = 'program, database, sequence and matrix must be defined';
        $app->log->error($message);
        $self->render_exception($message);
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
    $options{W} = $self->req->param('wordsize');

    my $report = $self->stash('server')->blastall(%options);

    if ( $report->fault ) {
        $self->report_error( $report->faultstring );
    }
    elsif ( $report->result =~ /sorry/i || $report->result !~ /BLAST/ ) {
        $self->report_error( $report->result );
    }
    else { # success
        ## write report to temporary file, return tmp file name
        my $tmp_dir = catdir(
            $self->app->config->{blast}->{tmp_folder}
                || $self->app->home->rel_dir('blast_output'),
            'results'
        );

        my $tmp = File::Temp->new( DIR => $tmp_dir, UNLINK => 0 );
        $tmp->print( $report->result );
        $tmp->close;

        my $filename = basename $tmp->filename;
        $self->app->log->debug($filename);
        $self->render( json => { file => $filename } );
    }
}

sub report {
    my ( $self, $c ) = @_;
    my $app = $self->app;

    # -- figure out the temp dir
    my $tmp_dir = $self->app->config->{blast}->{tmp_folder}
        || $self->app->home->rel_dir('blast_output');
    my $result_file = catfile( $tmp_dir, 'results',
        $self->stash('id') || $self->req->param('report_file') );

    if ( !$result_file ) {
        $self->redirect_to('/tools/blast');
        return;
    }

    my $html_hash = $self->blast_report( $result_file, $self->url_for->base );
    my $graph = $self->blast_graph( $tmp_dir, 'images', $result_file );

    #    use Data::Dumper;
    #    $self->app->log->debug(Dumper $html_hash->{top});

    $self->render(
        template   => 'blast/report',
        graph      => $graph,
        top        => $html_hash->{top},
        table      => $html_hash->{table},
        results    => $html_hash->{results},
        parameters => $html_hash->{parameters},
        statistics => $html_hash->{statistics},
        logo_link  => $app->config->{page}->{logo_link} || "/",
        no_header  => $self->req->param('noheader') || undef,
        title      => 'dictyBase BLAST Server: Report'
    );

    #unlink catfile($dir, $file);
}

sub report_error {
    my ( $self, $error_msg ) = @_;
    my $app = $self->app;
    my $email
        = '<a href="mailto:'
        . $app->config->{blast}->{site_admin_email} . '">'
        . $app->config->{blast}->{site_admin_email} . '</a>';
    $app->log->error($error_msg);
    my $display_msg =
        = "Sorry, an error occurred on our server. This is usually due to the BLAST report being too large. You can try reducing the number of alignments to show, increasing the E value and/or leaving the gapped alignment to 'True' and filtering 'On'. If you still get an error, please email $email with the sequence you were using for the BLAST and the alignment parameters.";
    $self->render_exception($display_msg);
}

1;

