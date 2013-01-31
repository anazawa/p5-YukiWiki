use inc::Module::Install;

all_from 'lib/YukiWiki.pm';

repository 'https://github.com/anazawa/p5-YukiWiki';

requires 'CGI::Application';
requires 'CGI::Application::Plugin::Forward';
requires 'CGI::Application::Plugin::ConfigAuto';
requires 'Encode';
requires 'Jcode';
requires 'parent';

test_requires 'Test::More';

tests 't/*.t';

WriteAll;
