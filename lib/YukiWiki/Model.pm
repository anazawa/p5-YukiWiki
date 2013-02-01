package YukiWiki::Model;
use strict;
use warnings;
use Carp qw();
use Fcntl qw(O_RDWR O_CREAT);

sub new {
    my $class  = shift;
    my $self   = bless { @_ }, $class;
    my $dbtype = $self->{cfg}->{modifier_dbtype};
    my $dir    = $self->can('dir') && $self->dir;

    return $self unless $dir;

    my %dbh;

    if ( $dbtype eq 'dbmopen' ) {
        dbmopen(%dbh, $dir, 0666) or Carp::croak("(dbmopen) $dir");
    }
    elsif ( $dbtype eq 'AnyDBM_File' ) {
        require AnyDBM_File;
        tie(%dbh, "AnyDBM_File", $dir, O_RDWR|O_CREAT, 0666)
           or Carp::croak("(tie AnyDBM_File) $dir");
    }
    else {
        require YukiWiki::DB;
        tie(%dbh, "YukiWiki::DB", $dir)
            or Carp::croak("(tie YukiWiki::DB) $dir");
    }

    $self->{dbh} = \%dbh;

    $self;
}

sub dbh { $_[0]->{dbh} }
sub cfg { $_[0]->{cfg} }

sub DESTROY {
    my $self   = shift;
    my $dbtype = $self->{cfg}->{modifier_dbtype};
    my $dbh    = delete $self->{dbh};

    return unless $dbh;

    if ( $dbtype eq 'dbmopen' ) {
        dbmclose(%$dbh);
    }
    else {
        untie(%$dbh);
    }
}

1;
