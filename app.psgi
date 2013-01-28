use strict;
use warnings;
use lib 'lib';
use Plack::Builder;
use YukiWiki;

my $app = YukiWiki->psgi_app({
    TMPL_PATH => 'tmpl/',
    PARAMS => {
        cfg_file => 'config.pl',
    },
});

builder {
    enable "Plack::Middleware::Static", path => qr{^/static/};
    $app;
};
