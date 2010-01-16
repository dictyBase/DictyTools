package dictyTools::Helper;

use IO::String;
use Bio::SearchIO;
use Bio::SearchIO::Writer::HTMLResultWriter;
use Bio::Graphics::Panel;
use Bio::SeqFeature::Generic;
use Bio::Seq::Oracleseq;
use Bio::SeqFeature::Gene::Exon;
use Bio::SeqFeature::Gene::Transcript;
use Module::Load;
use base qw/Mojo::Base/;
use version; our $VERSION = qv('1.0.0');

__PACKAGE__->attr('app');

sub blast_report {
    my ( $self, $report ) = @_;

    my $str;
    my $output = IO::String->new( \$str );

    my $stringio = IO::String->new($report);
    my $parser   = Bio::SearchIO->new(
        -fh     => $stringio,
        -format => 'blast'
    );

    my $feature_url = $self->app->config->{blast}->{blast_link_out};
    my $writer      = Bio::SearchIO::Writer::HTMLResultWriter->new(
        -nucleotide_url => $feature_url . '%s',
        -protein_url    => $feature_url . '%s'
    );

    $writer->title( sub { } );

    my $out = Bio::SearchIO->new( -writer => $writer, -fh => $output );
    $out->write_result( $parser->next_result, 1 );

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
    my ( $self, $report ) = @_;

    my $stringio = IO::String->new($report);
    my $parser   = Bio::SearchIO->new(
        -fh     => $stringio,
        -format => 'blast'
    );
    my $result = $parser->next_result;
    return if !$result;

    my $panel = Bio::Graphics::Panel->new(
        -length    => $result->query_length,
        -width     => 750,
        -pad_left  => 10,
        -pad_right => 10,
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
    );

    while ( my $hit = $result->next_hit ) {
        my $feature = Bio::SeqFeature::Generic->new(
            -score        => $hit->raw_score,
            -display_name => ( ( split( /\|/, $hit->name ) )[0] ),
        );
        while ( my $hsp = $hit->next_hsp ) {
            $feature->add_sub_SeqFeature( $hsp, 'EXPAND' );
        }
        $track->add_feature($feature);
    }
    my ( $url, $map, $mapname ) = $panel->image_and_map(
        -root  => $self->app->home->rel_dir('public'),
        -url   => '/tmp/',
        -title => '',
        -link  => '#$name'
    );
    return
          '<img src="' 
        . $url
        . '" usemap="#'
        . $mapname
        . '" border=1/>'
        . $map;
}

## -- dicty::Feature stuff

sub get_featureprop {
    my ( $self, $feature, $prop ) = @_;
    my $type =
        Chado::Cvterm->get_single_row( cvterm_id => $feature->type )->name;

    my ($prop_term) = Chado::Cvterm->get_single_row(
        cv_id => Chado::Cv->get_single_row( name => 'autocreated' ),
        name  => $prop
    );

    ## -- give it another shot
    if ( !$prop_term ) {
        $prop_term = Chado::Cvterm->get_single_row(
            cv_id => Chado::Cv->get_single_row( name => 'sequence' ),
            name  => $prop,
        );
    }

    return undef if !$prop_term;

    my $prop_row = Chado::Featureprop->get_single_row(
        type_id    => $prop_term->cvterm_id,
        feature_id => $feature->feature_id
    );

    return $prop_row ? $prop_row->value() : undef;
}

sub get_sequence {
    my ( $self, $feature, $type ) = @_;
    my $methodname = "calculate_" . lc($type) . "_seq";
    return $self->$methodname($feature);
}

sub calculate_protein_seq {
    my ( $self, $feature ) = @_;

    my $location =
        Chado::Featureloc->get_single_row(
        feature_id => $feature->feature_id );
    my $strand = $location->strand;

    ## -- Reference feature(chromosome/supergontig) bioperl object with sequence
    my $ref_feat =
        Chado::Feature->get_single_row(
        feature_id => $location->srcfeature->feature_id );
    my $ref_seq =
        Bio::Seq::Oracleseq->new( -primary_id => $ref_feat->feature_id );
    my $ref_bioperl = Bio::Seq->new( -primary_id => Chado::Dbxref->get_single_row( dbxref_id => $ref_feat->dbxref_id )->accession);
    $ref_bioperl->primary_seq($primary_seq);

    ## -- exons retrivial
    my @subfeatures = @{ $self->subfeatures($feature) };
    my @exon_feats = grep { $_->type_id->name eq 'CDS' } @subfeatures;

    my @exons;
    foreach my $exon_feat (@exon_feats) {
        my $locs     = $exon_feat->featureloc_feature_id();
        my $location = $locs->next();

        # chado is interbase coordinates, so add 1 to start of exons
        my $exon = Bio::SeqFeature::Gene::Exon->new(
            -start  => $location->fmin + 1,
            -end    => $location->fmax,
            -strand => $location->strand()
        );

        $exon->is_coding(1);
        push @exons, $exon;
    }

    # sort the exons by start ( order is reversed based on strand )
    @bexons = map { $_->[1] }
        sort { $strand * $a->[0] <=> $strand * $b->[0] }
        map { [ $_->start(), $_ ] } @exons;

    my $bioperl = Bio::SeqFeature::Gene::Transcript->new();

    # and add them to bioperl object
    map { $bioperl->add_exon($_) } @exons;

    ## -- attach reference feature bioperl
    $bioperl->attach_seq($ref_bioperl);

    my $translation_start =
        $self->app->helper->get_featureprop( $feature, 'translation_start' )
        || 1;

    my $protein_seq =
        $bioperl->cds->translate( undef, undef, $translation_start - 1 )
        ->seq();

    # check if protein has internal stop codon
    # and selenocysteine codons, if so, replace
    # internal *'s with U's

    my @seleno_feat = grep {
        Chado::Featureloc->get_single_row( feature_id => $_->feature_id )
            ->fmin >= $location->fmin
            && Chado::Featureloc->get_single_row(
            feature_id => $_->feature_id )->fmax < $location->fmax
        } Chado::Feature->search(
        type_id => Chado::Cvterm->get_single_row(
            name => 'stop_codon_redefined_as_selenocysteine'
        )
        );

    if ( $protein_seq =~ /.*\*.*\*$/ && @seleno_feat ) {
        $protein_seq =~ s/\*(?!$)/U/g;
    }
    return $protein_seq;
}

sub subfeatures {
    my ( $self, $feature ) = @_;

    my @features =
        grep { $_->is_deleted != 1 }
        map { Chado::Feature->get_single_row( feature_id => $_->id ) }
        map { $_->subject_id }
        Chado::Feature_Relationship->search( object_id => $feature->id );
    return \@features;
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



