package dictyTools::Helper;

use strict;
use IO::String;
use Bio::SearchIO;
use Bio::SearchIO::Writer::HTMLResultWriter;
use Bio::Graphics::Panel;
use Bio::SeqFeature::Generic;
use Bio::PrimarySeq;
use Bio::SeqFeature::Gene::Exon;
use Bio::SeqFeature::Gene::Transcript;
use Bio::SeqFeature::Generic;
use Module::Load;
use IO::File;

use base 'Mojo::Base';

use version; 
our $VERSION = qv('2.0.0');

__PACKAGE__->attr('app');

sub blast_report {
    my ( $self, $filename, $base_url ) = @_;

    my $report_file = IO::File->new( $filename, 'r' );
    my $report = join( "\n", <$report_file> );

    undef $report_file;

    my $str;
    my $output = IO::String->new( \$str );

    my $stringio = IO::String->new($report);
    my $parser   = Bio::SearchIO->new(
        -fh     => $stringio,
        -format => 'blast'
    );
    my $result = $parser->next_result;
    
    my $link     = $self->app->config->{blast}->{blast_link_out};
    $base_url = $base_url ? 'http://' . $base_url . $link : $link;

    my $writer = Bio::SearchIO::Writer::HTMLResultWriter->new(
        -nucleotide_url => $base_url . '%s',
        -protein_url    => $base_url . '%s'
    );

    $writer->title( sub { } );
    my $out = Bio::SearchIO->new( -writer => $writer, -fh => $output );
    $out->write_result( $result, 1 );

    my $header;
    my $table;
    my $results;
    my $parameters;
    my $statistics;

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

sub blast_graph {
    my ( $self, $filename ) = @_;

    my $report_file = IO::File->new( $filename, 'r' );
    my $report = join( "\n", <$report_file> );

    undef $report_file;

    my $stringio = IO::String->new($report);
    my $parser   = Bio::SearchIO->new(
        -fh     => $stringio,
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
        -start        => 1,
        -end          => $result->query_length,
        -display_name => ( ( split( /\|/, $result->query_name ) )[0] ),
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
        my $display_name = $display_name || $display_names[0];
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
        -root  => $self->app->home->rel_dir('public'),
        -url   => '/tmp/dictytools',
        -title => '',
        -link  => '#$name'
    );
    return
          '<img src="' 
        . $url
        . '" usemap="    #'
        . $mapname
        . '" border=1/>'
        . $map;
}

## -- dictyBase specific stuff

sub subfeatures {
    my ( $self, $feature ) = @_;

    my $resultset =
        $feature->search_related('feature_relationship_objects')
        ->search_related( 'subject', { is_deleted => 0 } );

    return $resultset;
}

sub get_featureprop {
    my ( $self, $feature, $prop ) = @_;
    return map { $_->value }
        grep { $_->type->name eq $prop } $feature->featureprops;
}

sub get_sequence {
    my ( $self, $feature, $type ) = @_;

    my ($sequence) = $self->get_featureprop( $feature, $type );
    return $sequence if $sequence;

    $self->add_bioperl($feature);
    $type =~ s{\s}{_}g;
    my $methodname = "calculate_" . lc($type);
    return $self->$methodname($feature);
}

sub get_header {
    my ( $self, $feature, $type ) = @_;

    my $feat_location = $feature->featureloc_features->first;
    my $ref_feat = $feat_location ? $feat_location->srcfeature : undef;

    my ($gene) =
        $feature->search_related('feature_relationship_subjects')
        ->search_related('object');

    my $header;
    $header .= "|" . $gene->dbxref->accession
        if $gene;
    $header .= "|" . $type . "|";
    $header .= " gene: " . $gene->uniquename if $gene;
    $header .= " on " . $ref_feat->type->name . ": " . $ref_feat->name
        if $ref_feat;
    $header .=
          " position "
        . ( $feat_location->fmin + 1 ) . " to "
        . $feat_location->fmax
        if $ref_feat;

    if ( $type =~ m{Genomic}i ) {
        $self->add_bioperl($feature);
        my $flank_up =
            $feature->{bioperl}->start > 1000
            ? 1000
            : $feature->{bioperl}->start - 1;
        my $flank_down =
            ( $feature->{bioperl}->entire_seq->length ) -
            $feature->{bioperl}->end > 1000
            ? 1000
            : ( $feature->{bioperl}->entire_seq->length ) -
            $feature->{bioperl}->end;

        $header .= " plus ";
        $header .=
            $feature->{bioperl}->strand ne "-1" ? $flank_up : $flank_down;
        $header .= " upstream and ";
        $header .=
            $feature->{bioperl}->strand ne "-1" ? $flank_down : $flank_up;
        $header .= " downstream basepairs";
        $header .= ", reverse complement"
            if ( $feature->{bioperl}->strand eq '-1' );
    }
    return $header;
}

sub add_bioperl {
    my ( $self, $feature ) = @_;

    my $feat_location = $feature->featureloc_features->first;
    my $strand        = $feat_location->strand;

    my $exon_rs =
        $self->subfeatures($feature)
        ->search( { 'type.name' => 'exon' }, { join => 'type' } );

    my @exons;
    foreach my $exon_feat ( $exon_rs->all ) {
        my $location = $exon_feat->featureloc_features->first;

        # chado is interbase coordinates, so add 1 to start of exons
        my $exon = Bio::SeqFeature::Gene::Exon->new(
            -start  => $location->fmin + 1,
            -end    => $location->fmax,
            -strand => $location->strand
        );
        push @exons, $exon;
    }

    # sort the exons by start ( order is reversed based on strand )
    my @exons = map { $_->[1] }
        sort { $strand * $a->[0] <=> $strand * $b->[0] }
        map { [ $_->start, $_ ] } @exons;

    my $bioperl = Bio::SeqFeature::Generic->new(
        -strand => $strand,
        -start  => $feat_location->fmin + 1,
        -end    => $feat_location->fmax,
    );

    # and add them to bioperl object
    map { $bioperl->add_SeqFeature($_) } @exons;

    # attach reference feature sequence if exists
    my $ref_feat = $feat_location->srcfeature;
    my $ref_seq  = Bio::PrimarySeq->new(
        -primary_id => $ref_feat->feature_id,
        -seq        => $ref_feat->residues,
    );
    my $ref_bioperl =
        Bio::Seq->new( -primary_id => $ref_feat->dbxref->accession );
    $ref_bioperl->primary_seq($ref_seq);

    $bioperl->attach_seq($ref_bioperl);
    $feature->{bioperl} = $bioperl;

    return;
}

sub calculate_spliced_transcript {
    my ( $self, $feature ) = @_;
    my $seq;

    my @exons = $feature->{bioperl}->get_SeqFeatures();
    map { $seq = $seq . $_->seq->seq() } @exons;
    return $seq;
}

sub calculate_dna_coding_sequence {
    my ( $self, $feature ) = @_;
    return $self->calculate_spliced_transcript($feature);
}

sub calculate_genomic {
    my ( $self, $feature ) = @_;

    my ( $genomic_start, $genomic_end, $flank_up, $flank_down );

    if ( $feature->{bioperl}->start() > 1000 ) {
        $genomic_start = $feature->{bioperl}->start() - 1000;
        $flank_up      = 1000;
    }
    else {
        $genomic_start = 1;
        $flank_up      = $feature->{bioperl}->start() - 1;
    }

    if ( ( $feature->{bioperl}->entire_seq->length ) -
        $feature->{bioperl}->end() > 1000 ) {
        $genomic_end = $feature->{bioperl}->end() + 1000;
        $flank_down  = 1000;
    }
    else {
        $genomic_end = ( $feature->{bioperl}->entire_seq->length );
        $flank_down =
            ( $feature->{bioperl}->entire_seq->length ) -
            $feature->{bioperl}->end();
    }

    my $seq =
          $feature->{bioperl}->strand ne "-1"
        ? $feature->{bioperl}
        ->entire_seq->trunc( $genomic_start, $genomic_end )
        : $feature->{bioperl}
        ->entire_seq->trunc( $genomic_start, $genomic_end )->revcom;
    return $seq->seq;
}

sub calculate_genomic_dna {
    my ( $self, $feature ) = @_;
    return $self->calculate_genomic($feature);
}

sub calculate_pseudogene {
    my ( $self, $feature ) = @_;
    return $feature->{bioperl}->seq->seq;
}

sub calculate_protein {
    my ( $self, $feature ) = @_;

    return $feature->search_related(
        'feature_relationship_objects',
        { 'type.name' => 'derived_from' },
        { join        => 'type' }
    )->search_related('subject')->first->residues;
}

1;    # Magic true value required at end of module

__END__

=head1 NAME

<dictyTools::Helper> - [Module providing some common methods for the entire application]


=head1 VERSION

This document describes <MODULE NAME> version 0.0.1


=head1 SYNOPSIS

use <MODULE NAME>;

=for author to fill in:
Brief code example(s) here showing commonest usage(s).
This section will be as far as many users bother reading
so make it as educational and exeplary as possible.


=head1 DESCRIPTION

=for author to fill in:
Write a full description of the module and its features here.
Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE 

=for author to fill in:
Write a separate section listing the public components of the modules
interface. These normally consist of either subroutines that may be
exported, or methods that may be called on objects belonging to the
classes provided by the module.

=head2 <METHOD NAME>

=over

=item B<Use:> <Usage>

[Detail text here]

=item B<Functions:> [What id does]

[Details if neccessary]

=item B<Return:> [Return type of value]

[Details]

=item B<Args:> [Arguments passed]

[Details]

=back

=head2 <METHOD NAME>

=over

=item B<Use:> <Usage>

[Detail text here]

=item B<Functions:> [What id does]

[Details if neccessary]

=item B<Return:> [Return type of value]

[Details]

=item B<Args:> [Arguments passed]

[Details]

=back


=head1 DIAGNOSTICS

=for author to fill in:
List every single error and warning message that the module can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
A full explanation of any configuration system(s) used by the
module, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be set. These descriptions must also include details of any
configuration language used.

<MODULE NAME> requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
A list of all the other modules that this module relies upon,
  including any restrictions on versions, and an indication whether
  the module is part of the standard Perl distribution, part of the
  module's distribution, or must be installed separately. ]

  None.


  =head1 INCOMPATIBILITIES

  =for author to fill in:
  A list of any modules that this module cannot be used in conjunction
  with. This may be due to name conflicts in the interface, or
  competition for system or program resources, or due to internal
  limitations of Perl (for example, many modules that use source code
		  filters are mutually incompatible).

  None reported.


  =head1 BUGS AND LIMITATIONS

  =for author to fill in:
  A list of known problems with the module, together with some
  indication Whether they are likely to be fixed in an upcoming
  release. Also a list of restrictions on the features the module
  does provide: data types that cannot be handled, performance issues
  and the circumstances in which they may arise, practical
  limitations on the size of data sets, special cases that are not
  (yet) handled, etc.

  No bugs have been reported.Please report any bugs or feature requests to
  dictybase@northwestern.edu



  =head1 TODO

  =over

  =item *

  [Write stuff here]

  =item *

  [Write stuff here]

  =back


  =head1 AUTHOR

  I<Siddhartha Basu>  B<siddhartha-basu@northwestern.edu>


  =head1 LICENCE AND COPYRIGHT

  Copyright (c) B<2003>, Siddhartha Basu C<<siddhartha-basu@northwestern.edu>>. All rights reserved.

  This module is free software; you can redistribute it and/or
  modify it under the same terms as Perl itself. See L<perlartistic>.


  =head1 DISCLAIMER OF WARRANTY

  BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
  FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
  OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
  PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
  EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
  ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
  YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
  NECESSARY SERVICING, REPAIR, OR CORRECTION.

  IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
  WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
  REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
  LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
  OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
  THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
		  RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
		  FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
  SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGES.


