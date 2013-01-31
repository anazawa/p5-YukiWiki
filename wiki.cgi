#!/usr/bin/perl
#!perl
#
# wiki.cgi - This is YukiWiki, yet another Wiki clone.
#
# Copyright (C) 2000-2004 by Hiroshi Yuki.
# <hyuki@hyuki.com>
# http://www.hyuki.com/yukiwiki/
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
##############################
# Libraries.
use strict;
use warnings;
use lib qw(lib);
use YukiWiki;
##############################

my $wiki = YukiWiki->new(
    TMPL_PATH => 'tmpl/',
    PARAMS => {
        cfg_file => 'config.pl',
    },
);

$wiki->run;

__END__

=head1 NAME

wiki.cgi - This is YukiWiki, yet another Wiki clone.

=head1 DESCRIPTION

YukiWiki is yet another Wiki clone.

YukiWiki can treat Japanese WikiNames (enclosed with [[ and ]]).
YukiWiki provides 'InterWiki' feature, RDF Site Summary (RSS),
and some embedded commands (such as [[#comment]] to add comments).

=head1 AUTHOR

Hiroshi Yuki <hyuki@hyuki.com> http://www.hyuki.com/yukiwiki/

=head1 LICENSE

Copyright (C) 2000-2006 by Hiroshi Yuki.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
