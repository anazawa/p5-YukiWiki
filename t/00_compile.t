use strict;
use warnings;
use Test::More tests => 11;

BEGIN {
    use_ok 'Algorithm::Diff';
    use_ok 'YukiWiki';
    use_ok 'YukiWiki::DB';
    use_ok 'YukiWiki::DiffText';
    use_ok 'YukiWiki::Model';
    use_ok 'YukiWiki::Model::Diff';
    use_ok 'YukiWiki::Model::Info';
    use_ok 'YukiWiki::Model::Page';
    use_ok 'YukiWiki::PluginManager';
    use_ok 'YukiWiki::RSS';
    use_ok 'YukiWiki::Util';
}
