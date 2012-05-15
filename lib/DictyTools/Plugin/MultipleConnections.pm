package DictyTools::Plugin::MultipleConnections;

use strict;
use Bio::Chado::Schema;
use Mojo::Base -base;
use base 'Mojolicious::Plugin';

sub register {
    my ( $self, $app ) = @_;
    die "need to load the yml_config\n" if not defined !$app->can('config');
    die
        "config must contain organism definitions with database connection parameters\n"
        if !$app->config->{organism};

    my $dbhash = $app->config->{database};
    my $model  = Bio::Chado::Schema->connect(
        $dbhash->{dsn}, $dbhash->{user},
        $dbhash->{password}, { LongReadLen => 2**25 }
    );
    $self->transform_model($model);
    $app->attr('model' => sub { return $model });

    my $connection_hash;
    foreach my $organism ( keys %{ $app->config->{organism} } ) {
        my $organism_conf = $app->config->{organism}->{$organism};
        next if !$organism_conf->{database};
        my $org_dbhash = $organism_conf->{database};
        my $org_model  = Bio::Chado::Schema->connect(
            $org_dbhash->{dsn}, $org_dbhash->{user},
            $org_dbhash->{password}, { LongReadLen => 2**25 }
        );
        $self->transform_model($org_model);
        $connection_hash->{$organism} = $org_model;
        $app->attr('connection_hash' => sub {return $connection_hash});
    }

    $app->helper(
        get_model => sub {
            my ( $c, $organism ) = @_;
            return $c->app->model if !$organism;
            my $hash = $c->app->connection_hash;
            return $hash->{$organism} ? $hash->{$organism} : $c->app->model;
        }
    );
}

sub transform_model {
    my ( $self, $connection ) = @_;

    my $cv_source  = $connection->source('Cv::Cvtermsynonym');
    my $class_name = 'Bio::Chado::Schema::' . $cv_source->source_name;
    $cv_source->remove_column('synonym');
    $cv_source->add_column(
        'synonym_' => {
            data_type   => 'varchar',
            is_nullable => 0,
            size        => 1024
        }
    );
    $class_name->add_column(
        'synonym_' => {
            data_type   => 'varchar',
            is_nullable => 0,
            size        => 1024
        }
    );
    $class_name->register_column(
        'synonym_' => {
            data_type   => 'varchar',
            is_nullable => 0,
            size        => 1024
        }
    );

    my $f_source = $connection->source('Sequence::Feature');
    $f_source->add_column(
        is_deleted => {
            data_type     => 'boolean',
            default_value => 'false',
            is_nullable   => 0,
            size          => 1
        }
    );

    my $f_class_name = 'Bio::Chado::Schema::' . $f_source->source_name;
    $f_source->add_column('is_deleted');
    $f_class_name->add_column('is_deleted');
    $f_class_name->register_column('is_deleted');

    $connection->source('Organism::Organism')->remove_column('comment');
}

1;
