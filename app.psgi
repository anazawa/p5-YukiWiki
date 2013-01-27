use strict;
use warnings;
use lib 'lib';
use YukiWiki;
use CGI::Emulate::PSGI;

CGI::Emulate::PSGI->handler(sub { YukiWiki->new->run });
