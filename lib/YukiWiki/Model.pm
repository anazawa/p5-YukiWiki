package YukiWiki::Model;
use strict;
use warnings;
use YukiWiki::DB;

sub new {
    my $class = shift;
    my $self  = bless { @_ }, $class;

    if ( $self->can('dir') ) {
        tie my %dbh, 'YukiWiki::DB', $self->dir;
        $self->{dbh} = \%dbh;
    }

    $self;
}

sub dbh { $_[0]->{dbh} }

1;
