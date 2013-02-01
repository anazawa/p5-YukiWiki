package YukiWiki::Model::Info;
use strict;
use warnings;
use parent qw(YukiWiki::Model);

my $ConflictChecker = 'ConflictChecker';
my $LastModified    = 'LastModified';
my $IsFrozen        = 'IsFrozen';
my $AdminPassword   = 'AdminPassword';

sub dir { $_[0]->cfg->{infoname} }

sub get {
    my ( $self, $page, $key ) = @_;
    my $info = $self->dbh->{$page} || q{};
    my %info = map { split(/=/, $_, 2) } split /\n/, $info;
    return $info{ $key };
}

sub set {
    my $self = shift;
    my $page = shift;
    my %args = @_;
    my $dbh  = $self->dbh;
    my %info = map { split(/=/, $_, 2) } split /\n/, $dbh->{$page};

    @info{ keys %args } = values %args;

    my $s = q{};
    while ( my ($k, $v) = each %info ) {
        $s .= "$k=$v\n";
    }

    $dbh->{ $page } = $s;
}

sub is_frozen {
    my ( $self, $page, $value ) = @_;
    return $self->set( $page, $IsFrozen, $value ) if defined $value;
    return $self->get( $page, $IsFrozen ) ? 1 : 0;
}

sub last_modified {
    my ( $self, $page, $value ) = @_;
    return $self->set( $page, $LastModified, $value ) if defined $value;
    return $self->get( $page, $LastModified );
}

sub conflict_checker {
    my ( $self, $page, $value ) = @_;
    return $self->set( $page, $ConflictChecker, $value ) if defined $value;
    return $self->get( $page, $ConflictChecker );
}

sub admin_password {
    my ( $self, $page, $value ) = @_;
    return $self->set( $page, $AdminPassword, $value ) if defined $value;
    return $self->get( $page, $AdminPassword );
}

1;
