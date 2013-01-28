use strict;
use warnings;
use lib 'lib';
use YukiWiki;
use CGI::Emulate::PSGI;

CGI::Emulate::PSGI->handler(sub {
    my $wiki = YukiWiki->new(
        PARAMS => {
            cfg_file => 'config.pl',
        },
    );

    $wiki->run;
});
