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
    my ( $self, $c ) = @_;
    my $app = $self->app;
    $self->render( json => $app->programs );
}

sub databases {
    my ( $self, $c ) = @_;
    my $app = $self->app;
    $self->render( json => $app->databases );
}

sub run {
    my ( $self, $c ) = @_;
    my $app = $self->app;

    my $params;
    foreach my $part ( @{ $self->req->content->parts } ) {
        $part->headers->content_disposition =~ m{name="(.+?)"};
        $params->{$1} = $part->asset->slurp;
    }

    if (!(     $params->{program}
            && $params->{database}
            && $params->{sequence}
            && $params->{matrix}
        )
        ) {
        my $message = 'program, database, sequence, matrix must be defined';
        $app->log->error($message);
        $self->render( text => $message, status => 500 );
        return;
    }
    my %options = (
        p => $params->{program},
        d => $params->{database},
        M => $params->{matrix},
        i => $params->{sequence}
    );

    $options{e} = $params->{evalue};
    $options{F} = $params->{filter};
    $options{g} = $params->{gapped};
    $options{b} = $params->{limit};
    $options{v} = $params->{limit};

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

    $self->render( text => $filename, status=>'404' );
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

    my $html_hash = $app->helper->blast_report( catfile( $dir, $file ), $c );
    my $graph = $app->helper->blast_graph( catfile( $dir, $file ) );

    $self->render(
        template   => $self->app->config->{blast}->{report_template},
        graph      => $graph,
        top        => $html_hash->{top},
        table      => $html_hash->{table},
        results    => $html_hash->{results},
        parameters => $html_hash->{parameters},
        statistics => $html_hash->{statistics},
        logo_link  => $app->config->{page}->{logo_link} || "/",
        no_header  => $self->req->param('noheader') || undef
    );

    #unlink catfile($dir, $file);
}

1;

