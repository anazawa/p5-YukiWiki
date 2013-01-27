use strict;
use warnings;
use Test::More tests => 7;

BEGIN {
    use_ok 'Algorithm::Diff';
    use_ok 'YukiWiki';
    use_ok 'YukiWiki::DiffText';
    use_ok 'YukiWiki::PluginManager';
    use_ok 'YukiWiki::RSS';
    use_ok 'YukiWiki::Util';
    use_ok 'YukiWiki::YukiWikiDB';
}
