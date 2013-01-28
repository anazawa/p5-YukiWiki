use strict;
use warnings;
use lib 'lib';
use CGI::Emulate::PSGI;
use Plack::Builder;
use YukiWiki;

my $app = CGI::Emulate::PSGI->handler(sub {
    my $wiki = YukiWiki->new(
        TMPL_PATH => 'tmpl/',
        PARAMS => {
            cfg_file => 'config.pl',
        },
    );

    $wiki->run;
});

builder {
    enable "Plack::Middleware::Static", path => qr{^/static/};
    $app;
};
