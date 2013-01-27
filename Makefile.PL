use inc::Module::Install;

all_from 'lib/YukiWiki.pm';

repository 'https://github.com/anazawa/p5-YukiWiki';

requires 'CGI::Application';
requires 'Encode';

test_requires 'Test::More';

tests 't/*.t';

WriteAll;
