package DictyTools::Plugin::BLASTHelpers;

use strict;
use Bio::SearchIO;
use Bio::SearchIO::Writer::HTMLResultWriter;
use Bio::Graphics::Panel;
use Bio::PrimarySeq;
use Bio::SeqFeature::Gene::Exon;
use Bio::SeqFeature::Generic;
use IO::File;
use IO::String;
use SOAP::Lite;
use File::Basename;

use base 'Mojolicious::Plugin';

sub register {
    my ( $self, $app ) = @_;
    die "need to load the yml_config\n" if not defined !$app->can('config');

    my $blast_server =
        SOAP::Lite->ns( $app->config->{blast}->{namespace} )
        ->proxy( $app->config->{blast}->{proxy} );

    my ( $programs, $databases );

    eval { ( $programs, $databases ) = @{ $blast_server->config->result } };
    if ($@) {
        $app->log->warn("Could not establish connection to BLAST server: $@");
        return;
    }

    $app->defaults( 'server'       => $blast_server );
    $app->defaults( 'programs'     => $programs );
    $app->defaults( 'databases'    => $databases );
    $app->defaults( 'is_connected' => 1 );

    $app->helper(
        blast_report => sub {
            my ( $c, $fh, $base_url ) = @_;

            my $str;
            my $output   = IO::String->new( \$str );
            my $parser   = Bio::SearchIO->new(
                -file     => $fh,
                -format => 'blast'
            );
            my $result = $parser->next_result;

            my $link = $c->app->config->{blast}->{blast_link_out};
            $base_url = $base_url ? $base_url . $link : $link;
            $base_url .= '/';

            my $writer = Bio::SearchIO::Writer::HTMLResultWriter->new(
                -nucleotide_url => $base_url . '%s',
                -protein_url    => $base_url . '%s'
            );

            $writer->title( sub { } );
            my $out =
                Bio::SearchIO->new( -writer => $writer, -fh => $output );
            $out->write_result( $result, 1 );

            my ( $header, $table, $results, $parameters, $statistics );
            if ( $str =~
                m{(.+?)(<table.+?table>)(.+?)<hr>.+?Parameters.+?(<table.+?table>).+?Statistics(.+?)<hr}s
                ) {
                $header     = $1;
                $table      = $2;
                $results    = $3;
                $parameters = $4;
                $statistics = $5;
            }
            $header  =~ s{<br>}{}g;
            $results =~ s{</br>}{}g;
            $table   =~ s{<br>}{}g;

            my $html_hash;
            $html_hash->{top}        = $header     if $header;
            $html_hash->{table}      = $table      if $table;
            $html_hash->{results}    = $results    if $results;
            $html_hash->{parameters} = $parameters if $parameters;
            $html_hash->{statistics} = $statistics if $statistics;
            return $html_hash;
        }
    );

    $app->helper(
        blast_graph => sub {
            my ( $c, $base_dir, $relative_image_dir,  $fh ) = @_;
            my $parser   = Bio::SearchIO->new(
                -file     => $fh,
                -format => 'blast'
            );
            my $result = $parser->next_result;
            return if !$result;

            my $panel = Bio::Graphics::Panel->new(
                -length    => $result->query_length,
                -width     => 720,
                -pad_left  => 5,
                -pad_right => 5,
            );
            my $full_length = Bio::SeqFeature::Generic->new(
                -start => 1,
                -end   => $result->query_length,
                -display_name =>
                    ( ( split( /\|/, $result->query_name ) )[0] ),
            );
            $panel->add_track(
                $full_length,
                -glyph   => 'arrow',
                -tick    => 2,
                -fgcolor => 'black',
                -double  => 1,
                -label   => 1,
            );
            my $track = $panel->add_track(
                -glyph     => 'generic',
                -label     => 1,
                -connector => 'dashed',
                -bgcolor   => 'blue',
                -height    => '5',

                #        -bump_limit => 5,
            );

            while ( my $hit = $result->next_hit ) {
                my @display_names = split( /\|/, $hit->name );
                my $display_name;
                foreach my $name (@display_names) {
                    $display_name = $name if $name =~ m{_};
                }
                $display_name ||= $display_names[0];
                my $feature = Bio::SeqFeature::Generic->new(
                    -score        => $hit->raw_score,
                    -display_name => ($display_name)
                );
                while ( my $hsp = $hit->next_hsp ) {
                    $feature->add_sub_SeqFeature( $hsp, 'EXPAND' );
                }
                $track->add_feature($feature);
            }

            my ( $url, $map, $mapname ) = $panel->image_and_map(
                -root  => $base_dir,
                -url   => $relative_image_dir, 
                -title => '',
                -link  => '#$name'
            );

            # rewrite the url path
            $url = $c->app->config->{blast}->{image_url}.'/'.basename($url);
            return
                  '<img src="' 
                . $url
                . '" usemap="    #'
                . $mapname
                . '" border=1/>'
                . $map;
        }
    );
}

1;
