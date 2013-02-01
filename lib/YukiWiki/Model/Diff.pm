package YukiWiki::Model::Diff;
use strict;
use warnings;
use parent qw(YukiWiki::Model);

sub dir { $_[0]->cfg->{diffname} }

1;
