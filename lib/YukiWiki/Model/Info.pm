package YukiWiki::Model::Info;
use strict;
use warnings;
use parent qw(YukiWiki::Model);

sub dir { $_[0]->{cfg}->{infoname} }

sub get {
    my ( $self, $page, $key ) = @_;
    my $info = $self->{dbh}->{$page} || q{};
    my %info = map { split(/=/, $_, 2) } split /\n/, $info;
    return $info{ $key };
}

sub set {
    my $self  = shift;
    my $page  = shift;
    my $key   = shift;
    my $value = shift;
    my $dbh   = $self->{dbh};
    my %info  = map { split(/=/, $_, 2) } split /\n/, $dbh->{$page};

    $info{ $key } = $value;

    my $s = q{};
    for my $k ( keys %info ) {
        $s .= "$k=$info{$k}\n";
    }

    $dbh->{ $page } = $s;
}

1;
