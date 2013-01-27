use strict;
use warnings;
use Test::More tests => 2;
use YukiWiki;

my $wiki = YukiWiki->new;

isa_ok $wiki, 'YukiWiki';

$wiki->init_resource;
isa_ok $wiki->param('resource'), 'HASH';
