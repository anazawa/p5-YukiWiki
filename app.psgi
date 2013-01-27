use strict;
use warnings;
use CGI::Emulate::PSGI;

CGI::Emulate::PSGI->handler(sub { do 'wiki.cgi'; main() });
