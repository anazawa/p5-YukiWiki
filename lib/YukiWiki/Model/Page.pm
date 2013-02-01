package YukiWiki::Model::Page;
use strict;
use warnings;
use parent qw(YukiWiki::Model);

sub dir { $_[0]->cfg->{dataname} }

sub interwiki {
    my $self = shift;

    $self->{interwiki} ||= do {
        my $content = $self->dbh->{InterWikiName} || q{};

        my %interwiki;
        while ( $content =~ /\[\[(\S+) +(\S+)\]\]/g ) {
            my ( $name, $url ) = ( $1, $2 );
            $interwiki{ $name } = $url;
        }

        \%interwiki;
    };
}

sub get_subjectline {
    my ( $self, $page, %option ) = @_;

    # Delimiter check.
    my $delim = $self->cfg->{subject_delimiter};
    if ( defined $option{delimiter} ) {
        $delim = $option{delimiter};
    }

    # Get the subject of the page.
    my $subject = $self->dbh->{$page};
    $subject =~ s/\r?\n.*//s;
    return "$delim$subject";
}

sub is_exist_page {
    my ( $self, $name ) = @_;

    if ( $self->cfg->{use_exists} ) {
        return exists $self->dbh->{$name};
    }
    else {
        return $self->dbh->{$name};
    }
}

1;
