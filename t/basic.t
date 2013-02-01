use strict;
use warnings;
use Test::More tests => 3;
use YukiWiki;

my $wiki = YukiWiki->new( PARAMS => { cfg_file => 'config.pl' } );

isa_ok $wiki, 'YukiWiki';
can_ok $wiki, qw(
    init_resource init_plugin
    do_read do_edit do_index do_write
    do_searchform do_search
    do_adminedit do_adminchangepasswordform do_adminchangepassword
    do_FrontPage do_error do_comment do_diff do_rss
    model
    conflict
    frozen_reject length_reject keyword_reject
    valid_password
    update_recent_changes update_rssfile
    send_mail_to_admin
);

$wiki->init_resource;
isa_ok $wiki->param('resource'), 'HASH';
