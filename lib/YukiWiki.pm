package YukiWiki; # Controller
use strict;
use warnings;
use parent qw(CGI::Application);
use CGI::Application::Plugin::ConfigAuto qw(cfg);
use CGI::Application::Plugin::Forward;
use Carp;
use YukiWiki::DiffText qw(difftext);
use YukiWiki::Formatter;
use YukiWiki::PluginManager;
use YukiWiki::RSS;
use YukiWiki::Util qw(escape);

our $VERSION = '2.1.3';

my $InterWikiName         = 'InterWikiName';
my $RecentChanges         = 'RecentChanges';
my $AdminChangePassword   = 'AdminChangePassword';
my $CompletedSuccessfully = 'CompletedSuccessfully';
my $FrontPage             = 'FrontPage';
my $IndexPage             = 'IndexPage';
my $SearchPage            = 'SearchPage';
my $CreatePage            = 'CreatePage';
my $ErrorPage             = 'ErrorPage';
my $RssPage               = 'RssPage';
my $AdminSpecialPage      = 'Admin Special Page'; # must include spaces.

my $wiki_name      = qr{\b([A-Z][a-z]+([A-Z][a-z]+)+)\b};
my $bracket_name   = qr{\[\[(\S+?)\]\]};
my $embedded_name  = qr{\[\[(#\S+?)\]\]};
my $interwiki_name = qr{([^:]+):([^:].*)};

my $embed_comment  = '[[#comment]]';
my $embed_rcomment = '[[#rcomment]]';

sub setup {
    my $self = shift;

    $self->param(
        debug => 0,
        kanjicode => 'utf8',
        charset => 'UTF-8',
        lang => 'ja',
        fixedpage => {
            $IndexPage => 1,
            $CreatePage => 1,
            $ErrorPage => 1,
            $RssPage => 1,
            $RecentChanges => 1,
            $SearchPage => 1,
            $AdminChangePassword => 1,
            $CompletedSuccessfully => 1,
            $FrontPage => $self->cfg('use_FixedFrontPage'),
        },
        page_command => {
            $IndexPage => 'index',
            $SearchPage => 'searchform',
            $CreatePage => 'create',
            $RssPage => 'rss',
            $AdminChangePassword => 'adminchangepasswordform',
            $FrontPage => 'FrontPage',
        },
        model => {},
        mypage => $FrontPage,
    );

    $self->init_resource;
    $self->init_plugin;

    $self->mode_param('mycmd');
    $self->start_mode('FrontPage');
    $self->error_mode('do_error');

    $self->run_modes(
        read                    => 'do_read', # Page
        edit                    => 'do_edit', # Page
        adminedit               => 'do_adminedit', # Page
        adminchangepasswordform => 'do_adminchangepasswordform',
        adminchangepassword     => 'do_adminchangepassword',
        write                   => 'do_write', # Page
        index                   => 'do_index', # Page
        searchform              => 'do_searchform', # Search
        search                  => 'do_search', # Search
        create                  => 'do_create', # Page
        createresult            => 'do_createresult',
        FrontPage               => 'do_FrontPage', # Page
        comment                 => 'do_comment',
        rss                     => 'do_rss',
        diff                    => 'do_diff',
    );

    $self->header_add( -charset => $self->param('charset') );

    return;
}

sub kanjicode { $_[0]->param('kanjicode') }

sub fixedpage { $_[0]->param('fixedpage') }

sub page_command { $_[0]->param('page_command') }

sub cgiapp_prerun { # URL mapping
    my $self   = shift;
    my $query  = $self->query;
    my $mycmd  = $query->param('mycmd');
    my $mypage = YukiWiki::Util::decode( $query->param('mypage') || q{} );

    $mypage ||= do {
        ( my $path_info = $query->path_info ) =~ s{^/}{};
        YukiWiki::Util::decode( $path_info );
    };


    if ( my $page_command = $self->page_command->{$mypage} ) {
        unless ( $mypage eq $FrontPage ) {
            $self->prerun_mode( $page_command );
            $self->param( mypage => $mypage );
        }
    }
    elsif ( $mypage =~ /^($wiki_name)$/ ) {
        $self->prerun_mode('read') unless $mycmd;
        $self->param( mypage => $1 );
    }

    # mypreview_edit        -> do_edit, with preview.
    # mypreview_adminedit   -> do_adminedit, with preview.
    # mypreview_write       -> do_write, without preview.
    for my $key ( $query->param ) {
        if ( $key =~ /^mypreview_(.*)$/ ) {
            $self->prerun_mode( $1 );
            $self->param( mypreview => 1 );
        }
    }

    my $kanjicode = $self->param('kanjicode');
    my $mymsg     = $query->param('mymsg');
    my $myname    = $query->param('myname');

    $self->param(
        mymsg   => YukiWiki::Util::code_convert( \$mymsg, $kanjicode ),
        myname  => YukiWiki::Util::code_convert( \$myname, $kanjicode ),
        mytouch => scalar $query->param('mytouch'),
    );

    $self->add_callback( load_tmpl => 'before_load_tmpl' );

    return;
}

sub before_load_tmpl {
    my ( $self, $ht_params, $tmpl_params ) = @_;

    $ht_params->{die_on_bad_params} = 0;
    $ht_params->{global_vars}       = 1;

    $tmpl_params->{VERSION} = $VERSION;
    $tmpl_params->{lang}    = $self->param('lang');
    $tmpl_params->{charset} = $self->param('charset');
    $tmpl_params->{url_cgi} = $self->cfg('url_cgi');

    return;
}

sub model {
    my $self  = shift;
    my $class = join '::', 'YukiWiki::Model', shift;
    my $model = $self->param('model');

    unless ( exists $model->{$class} ) {
        ( my $file = $class ) =~ s{::}{/}g;
        require "$file.pm";
        $model->{ $class } = $class->new( cfg => scalar $self->cfg );
    }

    $model->{ $class };
}

sub database { $_[0]->model('Page')->dbh }

sub teardown {
    my $self = shift;
    $self->delete('model');
}

sub do_read {
    my $self   = shift;
    my $mypage = $self->param('mypage');

    return join q{}, (
        $self->render_header,
        $self->render_content( $self->model('Page')->dbh->{$mypage} ),
        $self->render_footer,
    );
}

sub do_edit {
    my $self   = shift;
    my $mypage = $self->param('mypage');
    my $page   = unarmor_name( armor_name($mypage) );

    $self->param( mypage => $page );

    my $output = $self->render_header;

    if ( $self->is_frozen or !$self->is_editable ) {
        $output .= $self->render_message( $self->resource->{cantchange} );
    }
    else {
        $output .= $self->render_editform(
            $self->database->{ $page },
            $self->model('Info')->conflict_checker( $page ),
            admin => 0,
        );
    }

    $output .= $self->render_footer;

    $output;
}

sub do_adminedit {
    my $self   = shift;
    my $mypage = $self->param('mypage');
    my $page   = unarmor_name( armor_name($mypage) );
    my $output = $self->render_header( $page );

    if ( $self->is_editable($page) ) {
        $output .= $self->render_message( $self->resource->{passwordneeded} );
        $output .= $self->render_editform(
            $self->model('Page')->dbh->{ $page },
            $self->model('Info')->conflict_checker( $page ),
            admin => 1,
        );
    }
    else {
        $output .= $self->render_message( $self->resource->{cantchange} );
    }

    $output .= $self->render_footer( $page );

    $output;
}

sub do_adminchangepasswordform {
    my $self     = shift;
    my $resource = $self->param('resource');
    my $output   = $self->render_header;

    $output .= do {
        my $template = $self->load_tmpl;

        $template->param(
            oldpassword          => $resource->{oldpassword},
            newpassword          => $resource->{newpassword},
            newpassword2         => $resource->{newpassword2},
            changepasswordbutton => $resource->{changepasswordbutton},
        );

        $template->output;
    };

    $output .= $self->render_footer;

    $output;
}

sub do_adminchangepassword {
    my $self           = shift;
    my $query          = $self->query;
    my $myoldpassword  = $query->param('myoldpassword');
    my $mynewpassword  = $query->param('mynewpassword');
    my $mynewpassword2 = $query->param('mynewpassword2');
    my $info           = $self->model('Info');

    if ( $mynewpassword ne $mynewpassword2 ) {
        croak $self->resource->{passwordmismatcherror};
    }

    my $validpassword_crypt = $info->admin_password( $AdminSpecialPage );

    if ( $validpassword_crypt ) {
        unless ( $self->valid_password($myoldpassword) ) {
            $self->send_mail_to_admin(<<"EOD", "AdminChangePassword");
myoldpassword=$myoldpassword
mynewpassword=$mynewpassword
mynewpassword2=$mynewpassword2
EOD
            croak $self->resource->{passworderror};
        }
    }

    my $crypted = do {
        my ($sec, $min, $hour, $day, $mon, $year, $weekday) = localtime(time);
        my @token = ('0'..'9', 'A'..'Z', 'a'..'z');
        my $salt1 = $token[(time | $$) % scalar(@token)];
        my $salt2 = $token[($sec + $min*60 + $hour*60*60) % scalar(@token)];
        crypt( $mynewpassword, "$salt1$salt2" );
    };

    $info->admin_password( $AdminSpecialPage => $crypted );

    return join q{}, (
        $self->render_header( $CompletedSuccessfully ),
        $self->render_message( $self->resource->{passwordchanged} ),
        $self->render_footer( $CompletedSuccessfully ),
    );
}

sub do_index {
    my $self   = shift;
    my $page   = $self->model('Page');
    my $output = $self->render_header;

    my @pages;
    for my $name ( sort keys %{ $page->dbh } ) {
        # print qq(<li>@{[&get_info($page, $info_IsFrozen)]}</li>);
        # print qq(<li>@{[0 + &is_frozen($page)]}</li>);
        push @pages, +{
            name        => $name,
            is_editable => $self->is_editable( $name ),
            subjectline => $page->get_subjectline( $name ),
        };
    }

    $output .= do {
        my $template = $self->load_tmpl;
        $template->param( pages => \@pages );
        $template->output;
    };

    $output .= $self->render_footer;

    $output;
}

sub do_write {
    my $self     = shift;
    my $query    = $self->query;
    my $resource = $self->param('resource');
    my $database = $self->database;
    my $info     = $self->model('Info');
    my $mypage   = $self->param('mypage');
    my $mymsg    = $self->param('mymsg');

    return if $self->keyword_reject;
    return if $self->frozen_reject;
    return if $self->length_reject;

    unless ( $self->is_editable ) {
        return join q{}, (
            $self->render_header,
            $self->render_message( $self->resource->{cantchange} ),
            $self->render_footer,
        );
    }

    if ( my $output = $self->conflict($mypage, $mymsg) ) {
        return $output;
    }

    # Making diff
    do {
        my @msg1 = split /\r?\n/, $database->{$mypage};
        my @msg2 = split /\r?\n/, $mymsg;
        $self->model('Diff')->dbh->{$mypage} = difftext( \@msg1, \@msg2 );
    };

    unless ( $mymsg ) {
        $self->send_mail_to_admin( $mypage, "Delete" );

        delete $database->{ $mypage };
        delete $info->dbh->{ $mypage };

        $self->update_recent_changes if $self->param('mytouch');

        return join q{}, (
            $self->render_header,
            $self->render_message( $resource->{deleted} ),
            $self->render_footer,
        );
    }

    $database->{ $mypage } = $mymsg;
    $self->send_mail_to_admin( $mypage, "Modify" );
    $info->conflict_checker( $mypage => scalar localtime );

    if ( $self->param('mytouch') ) {
        $info->last_modified( $mypage => scalar localtime );
        $self->update_recent_changes;
    }

    $info->is_frozen( $mypage => 0 + $self->query->param('myfrozen') );

    my $output = $self->render_header( $CompletedSuccessfully );
    $output .= $self->render_message( $resource->{saved} );
    $output .= $self->render_content(
        "$resource->{continuereading} @{[&armor_name($mypage)]}"
    );
    $output .= $self->render_footer( $CompletedSuccessfully );
    return $output;

}

sub do_searchform {
    my $self = shift;

    return join q{}, (
        $self->render_header,
        $self->render_searchform( q{} ),
        $self->render_footer,
    );
}

sub do_search {
    my $self  = shift;
    my $mymsg = $self->param('mymsg');
    my $word  = YukiWiki::Util::escape( $mymsg );
    my $page  = $self->model('Page');

    $self->param( mypage => $SearchPage );

    my $output = $self->render_header;

    $output .= $self->render_searchform( $word );

    my @pages;
    while ( my ($name, $content) = each %{ $page->dbh } ) {
        next if $name eq $RecentChanges;
        next if $content !~ /\Q$mymsg\E/ and $name !~ /\Q$mymsg\E/;

        push @pages, +{
            name        => $name,
            subjectline => $page->get_subjectline( $name ),
        };
    }

    @pages = sort { $a->{name} cmp $b->{name} } @pages;

    if ( @pages ) {
        my $template = $self->load_tmpl;
        $template->param( pages => \@pages );
        $output .= $template->output;
    }
    else {
        $output .= $self->render_message( $self->resource->{notfound} );
    }

    $output .= $self->render_footer;

    $output;
}

sub do_create {
    my $self     = shift;
    my $resource = $self->param('resource');
    my $output   = $self->render_header;

    $output .= do {
        my $template = $self->load_tmpl;

        $template->param(
            newpagename  => $resource->{newpagename},
            createbutton => $resource->{createbutton},
        );

        $template->output;
    };

    $output .= $self->render_footer;

    $output;
}

sub do_FrontPage {
    my $self = shift;

    unless ( $self->fixedpage->{$FrontPage} ) {
        $self->param( mypage => $FrontPage );
        return $self->forward('read');
    }

    my $file_FrontPage = $self->cfg('file_FrontPage');
    open my $fh, "< $file_FrontPage" or croak "($file_FrontPage)";
    my $content = join q{}, <$fh>;
    YukiWiki::Util::code_convert( \$content, $self->kanjicode );
    close $fh;

    return join q{}, (
        $self->render_header,
        $self->render_content( $content ),
        $self->render_footer,
    );
}

sub do_comment {
    my $self    = shift;
    my $mypage  = $self->param('mypage');
    my $myname  = $self->param('myname');
    my $mymsg   = $self->param('mymsg');
    my $content = $self->model('Page')->dbh->{ $mypage };
    my $datestr = YukiWiki::Util::get_now();
    my $namestr = $myname ? " ''[[$myname]]'' : " : " ";

    if ($content =~ s/(^|\n)(\Q$embed_comment\E)/$1- $datestr$namestr$mymsg\n$2/) {
        ;
    }
    else {
        $content =~ s/(^|\n)(\Q$embed_rcomment\E)/$1$2\n- $datestr$namestr$mymsg/;
    }

    return $self->forward('read') unless $mymsg;

    $self->param(
        mymsg   => $content,
        mytouch => 'on',
    );

    $self->forward('write');
}

sub do_diff {
    my $self     = shift;
    my $resource = $self->param('resource');
    my $mypage   = $self->param('mypage');

    return $self->forward('read') unless $self->is_editable;

    my $diff = YukiWiki::Util::escape( $self->model('Diff')->dbh->{$mypage} );

    my @lines;
    for ( split /\n/, $diff ) {
        if ( /^\+(.*)/ ) {
            push @lines, +{ line => $1, is_added => 1 };
        }
        elsif ( /^\-(.*)/ ) {
            push @lines, +{ line => $1, is_deleted => 1 };
        }
        elsif ( /^\=(.*)/ ) {
            push @lines, +{ line => $1, is_same => 1 };
        }
        else {
            push @lines, +{ line => $_ };
        }
    }

    my $output = $self->render_header;

    $output .= do {
        my $template = $self->load_tmpl;

        $template->param(
            difftitle  => $resource->{difftitle},
            diffnotice => $resource->{diffnotice},
            lines      => \@lines,
        );

        $template->output;
    };

    $output .= $self->render_footer;

    $output;
}

sub do_rss {
    my $self = shift;

    if ( $self->cfg('file_rss') ) {
        $self->header_type('redirect');
        $self->header_props( -url => $self->cfg('modifier_rss_about') );
    }
}

sub do_error {
    my ( $self, $msg ) = @_;

    return join q{}, (
        $self->render_header,
        qq(<p><strong class="error">$msg</strong></p>),
        $self->render_plugin_log,
        $self->render_footer,
    );
}

sub render_header {
    my $self     = shift;
    my $page     = shift || $self->param('mypage');
    my $template = $self->load_tmpl('header.html');
    my $resource = $self->param('resource');
    my $mycmd    = $self->get_current_runmode;

    $template->param(
        page                 => $page,
        bodyclass            => 'normal',
        editable             => 0,
        admineditable        => 0,
        subjectline          => $self->get_subjectline( $page ),
        escapedpage          => YukiWiki::Util::escape( $page ),
        cookedpage           => YukiWiki::Util::encode( $page ),
        IndexPage            => $IndexPage,
        CreatePage           => $CreatePage,
        SearchPage           => $SearchPage,
        FrontPage            => $FrontPage,
        RecentChanges        => $RecentChanges,
        modifier_mail        => $self->cfg('modifier_mail'),
        url_stylesheet       => $self->cfg('url_stylesheet'),
        modifier_rss_about   => $self->cfg('modifier_rss_about'),
        admineditthispage    => $resource->{admineditthispage},
        admineditbutton      => $resource->{admineditbutton},
        editthispage         => $resource->{editthispage},
        editbutton           => $resource->{editbutton},
        diffbutton           => $resource->{diffbutton},
        createbutton         => $resource->{createbutton},
        indexbutton          => $resource->{indexbutton},
        rssbutton            => $resource->{rssbutton},
        searchbutton         => $resource->{searchbutton},
        recentchangesbutton  => $resource->{recentchangesbutton},
        searchthispagebutton => $resource->{searchthispagebutton},
    );

    if ( $self->is_frozen($page) and $mycmd =~ /^(read|write)$/ ) {
        $template->param(
            admineditable => 1,
            bodyclass     => "frozen",
        );
    }
    elsif ( $self->is_editable($page) and $mycmd =~ /^(read|write)$/ ) {
        $template->param(
            admineditable => 1,
            editable      => 1,
        );
    }

    $template->output;
}

sub render_footer {
    my $self = shift;
    my $page = shift || $self->param('mypage');
    my $tmpl = $self->load_tmpl('foot.html');

    $tmpl->param(
        page          => $page,
        modifier_url  => $self->cfg('modifier_url'),
        modifier_name => $self->cfg('modifier_name'),
        icontag       => $self->cfg('icontag'),
    );

    $tmpl->output;
}

sub render_content {
    my ( $self, $rawcontent ) = @_;
    $self->text_to_html( $rawcontent, toc => 1 );
}

sub render_message {
    my ( $self, $msg ) = @_;
    my $tmpl = $self->load_tmpl('message.html');
    $tmpl->param( msg => $msg );
    $tmpl->output;
}

sub render_searchform {
    my $self = shift;
    my $word = shift;
    my $tmpl = $self->load_tmpl('searchform.html');

    $tmpl->param(
        word         => $word,
        searchbutton => $self->resource->{searchbutton},
    );

    $tmpl->output;
}

sub render_editform {
    my $self            = shift;
    my $mymsg           = shift;
    my $conflictchecker = shift;
    my %mode            = @_;
    my $query           = $self->query;
    my $mypage          = $self->param('mypage');
    my $mypreview       = $self->param('mypreview');
    my $resource        = $self->param('resource');
    my $tmpl            = $self->load_tmpl('editform.html');
    my $mypassword      = $query->param('mypassword');

    if ( $mypreview ) {
        $mymsg = $self->param('mymsg');
        if ( $mymsg and !$mode{conflict} ) {
            $tmpl->param( renderedmymsg => $self->render_content($mymsg) );
        }
    }

    $tmpl->param(
        mypreview         => $mypreview,
        admin             => $mode{admin},
        conflict          => $mode{conflict},
        edit              => $mode{admin} ? 'adminedit' : 'edit',
        escapedmypassword => YukiWiki::Util::escape( $mypassword ),
        escapedmypage     => YukiWiki::Util::escape( $mypage ),
        mymsg             => YukiWiki::Util::escape( $mymsg ),
        conflictchecker   => $conflictchecker,
        frozen            => $self->is_frozen,
        cols              => $self->cfg('cols'),
        rows              => $self->cfg('rows'),
        frozenpassword    => $resource->{frozenpassword},
        frozenbutton      => $resource->{frozenbutton},
        notfrozenbutton   => $resource->{notfrozenbutton},
        touch             => $resource->{touch},
        previewbutton     => $resource->{previewbutton},
        savebutton        => $resource->{savebutton},
        previewtitle      => $resource->{previewtitle},
        previewnotice     => $resource->{previewnotice},
        previewempty      => $resource->{previewempty},
    );

    unless ( $mode{conflict} ) {
        # Show the format rule.
        my $file_format = $self->cfg('file_format');
        open my $fh, "< $file_format" or die "($file_format)";
        my $content = join q{}, <$fh>;
        YukiWiki::Util::code_convert( \$content, $self->kanjicode );
        close $fh;
        $tmpl->param( file_format => $self->text_to_html($content, toc => 0) );
    }

    unless ( $mode{conflict} ) {
        # Show plugin information.
        my $plugin_usage_tmpl = $self->load_tmpl('plugin_usage.txt');

        $plugin_usage_tmpl->param(
            available_plugins        => $resource->{available_plugins},
            plugin_usage_name        => $resource->{plugin_usage_name},
            plugin_usage_version     => $resource->{plugin_usage_version},
            plugin_usage_author      => $resource->{plugin_usage_author},
            plugin_usage_syntax      => $resource->{plugin_usage_syntax},
            plugin_usage_description => $resource->{plugin_usage_description},
            plugin_usage_example     => $resource->{plugin_usage_example},
            PLUGINS                  => $self->plugin_manager->usage,
        );

        my $plugin_usage = $plugin_usage_tmpl->output;
        YukiWiki::Util::code_convert( \$plugin_usage, $self->kanjicode );
        $plugin_usage = $self->text_to_html( $plugin_usage, toc => 0 );

        $tmpl->param( plugin_usage => $plugin_usage );
    }

    $tmpl->output;
}

sub render_plugin_log {
    my $self = shift;

    if ( $self->param('debug') ) {
        my $log = $self->plugin_manager->{log};
        return "<pre>(print_plugin_log)\n" . join("\n", @{$log}) . "</pre>";
    }

    return q{};
}

sub text_to_html {
    my ( $self, $txt, %option ) = @_;

    my $formatter = YukiWiki::Formatter->new(
        editchar       => $self->cfg('editchar'),
        use_autoimg    => $self->cfg('use_autoimg'),
        plugin_manager => $self->plugin_manager,
        resource       => $self->param('resource'),
        interwiki      => $self->model('Page')->interwiki,
        context        => $self,
        txt            => $txt,
        option         => \%option,
    );

    $formatter->as_string;
}

sub update_recent_changes {
    my $self       = shift;
    my $mypage     = $self->param('mypage');
    my $database   = $self->database;
    my @oldupdates = split /\r?\n/, $database->{$RecentChanges};

    my $update = join(' ',
        '-',
        YukiWiki::Util::get_now(),
        armor_name( $mypage ),
        $self->get_subjectline( $mypage ),
    );

    my @updates;
    for ( @oldupdates ) {
        /^\- \d\d\d\d\-\d\d\-\d\d \(...\) \d\d:\d\d:\d\d (\S+)/; # date format.
        my $name = unarmor_name( $1 );
        push @updates, $_ if $self->is_exist_page($name) and $name ne $mypage;
    }

    unshift @updates, $update if $self->is_exist_page( $mypage );
    splice @updates, $self->cfg('maxrecent') + 1;

    $database->{ $RecentChanges } = join "\n", @updates;

    if ( my $file_touch = $self->cfg('file_touch') ) {
        open my $fh, "> $file_touch";
        print $fh localtime() . "\n";
        close $fh;
    }

    $self->update_rssfile if $self->cfg('file_rss');

    return;
}

sub get_subjectline {
    my ( $self, $page, %option ) = @_;
    return q{} unless $self->is_editable( $page );
    $self->model('Page')->get_subjectline( $page, %option )
}

sub send_mail_to_admin {
    my $self              = shift;
    my $page              = shift;
    my $mode              = shift;
    my $modifier_sendmail = $self->cfg('modifier_sendmail');

    return unless $modifier_sendmail;

    my $remote_addr   = $self->query->remote_addr;
    my $remote_host   = $self->query->remote_host;
    my $database      = $self->database;
    my $modifier_mail = $self->cfg('modifier_mail');

    my $message = <<"EOD";
To: $modifier_mail
From: $modifier_mail
Subject: [Wiki/$mode]
MIME-Version: 1.0
Content-Type: text/plain; charset=ISO-2022-JP
Content-Transfer-Encoding: 7bit

--------
MODE = $mode
REMOTE_ADDR = $remote_addr
REMOTE_HOST = $remote_host
--------
$page
--------
$database->{$page}
--------
EOD

    YukiWiki::Util::code_convert(\$message, 'jis');
    open(MAIL, "| $modifier_sendmail");
    print MAIL $message;
    close(MAIL);
}

sub is_editable {
    my $self = shift;
    my $page = shift || $self->param('mypage');

    if ( !$page ) {
        return 0;
    }
    elsif ( is_bracket_name($page) ) {
        return 0;
    }
    elsif ( $self->fixedpage->{$page} ) {
        return 0;
    }
    elsif ( $page =~ /\s/ ) {
        return 0;
    }
    elsif ( $page =~ /^\#/ ) {
        return 0;
    }
    elsif ( $page =~ /^$interwiki_name$/ ) {
        return 0;
    }

    return 1;
}

# armor_name:
#   WikiName -> WikiName
#   not_wiki_name -> [[not_wiki_name]]
sub armor_name {
    my $name = shift;
    $name =~ /^$wiki_name$/ ? $name : "[[$name]]";
}

# unarmor_name:
#   [[bracket_name]] -> bracket_name
#   WikiName -> WikiName
sub unarmor_name {
    my $name = shift;
    $name =~ /^$bracket_name$/ ? $1 : $name;
}

sub is_bracket_name {
    my $name = shift;
    $name =~ /^$bracket_name$/ ? 1 : 0;
}

sub init_resource {
    my $self          = shift;
    my $kanjicode     = $self->param('kanjicode');
    my $file_resource = $self->cfg('file_resource');

    open my $fh, "< $file_resource" or croak "(resource)";

    my %resource;
    while ( <$fh> ) {
        chomp;
        next if /^#/;
        my ( $key, $value ) = split /=/, $_, 2;
        $resource{ $key } = YukiWiki::Util::code_convert(\$value, $kanjicode);
    }

    close $fh;

    $self->param( resource => \%resource );

    return;
}

sub resource { $_[0]->param('resource') }

sub conflict {
    my $self              = shift;
    my $page              = shift;
    my $rawmsg            = shift;
    my $myConflictChecker = $self->query->param('myConflictChecker');

    if ( $myConflictChecker eq $self->model('Info')->conflict_checker($page) ) {
        return 0;
    }

    open(FILE, $self->cfg('file_conflict')) or die "(conflict)";
    my $content = join('', <FILE>);
    YukiWiki::Util::code_convert(\$content, $self->kanjicode);
    close(FILE);

    my $output = $self->render_header( $page );
    $output .= $self->render_content( $content );

    $output .= $self->render_editform(
        $rawmsg,
        $myConflictChecker,
        frozen => 0,
        conflict => 1,
    );

    $output .= $self->render_footer( $page );

    $output;
}

sub interwiki { $_[0]->model('Page')->interwiki }

sub frozen_reject {
    my $self         = shift;
    my $isfrozen     = $self->model('Info')->is_frozen($self->param('mypage'));
    my $willbefrozen = $self->query->param('myfrozen');
    my $mypassword   = $self->query->param('mypassword');

    if ( not $isfrozen and not $willbefrozen ) {
        # You need no check.
        return 0;
    }
    elsif ( $self->valid_password($mypassword) ) {
        # You are admin.
        return 0;
    }

    croak $self->resource->{passworderror};
}

sub length_reject {
    my $self               = shift;
    my $max_message_length = $self->cfg('max_message_length');

    return 0 if $max_message_length < 0;

    if ( $max_message_length < length $self->param('mymsg') ) {
        croak $self->resource->{toolongpost} . $max_message_length;
    }

    return 0;
}

sub valid_password {
    my ( $self, $givenpassword ) = @_;
    my $validpassword_crypt
        = $self->model('Info')->admin_password( $AdminSpecialPage );
    crypt( $givenpassword, $validpassword_crypt ) eq $validpassword_crypt;
}

sub is_frozen {
    my $self = shift;
    my $page = shift || $self->param('mypage');
    $self->model('Info')->is_frozen( $page );
}

sub embedded_to_html {
    my $self          = shift;
    my $embedded      = shift;
    my $mypage        = $self->param('mypage');
    my $escapedmypage = YukiWiki::Util::escape( $mypage );

    if ( $embedded eq $embed_comment or $embedded eq $embed_rcomment ) {
        my $conflictchecker = $self->model('Info')->conflict_checker($mypage);
        my $resource        = $self->param('resource');
        my $tmpl            = $self->load_tmpl('commentform.html');

        $tmpl->param(
            escapedmypage   => $escapedmypage,
            conflictchecker => $conflictchecker,
            yourname        => $resource->{yourname},
            commentbutton   => $resource->{commentbutton},
        );

        return $tmpl->output; 
    }

    return $embedded;
}

sub is_exist_page { shift->model('Page')->is_exist_page(@_) }

# Initialize plugins.
sub init_plugin {
    my $self = shift;

    $self->param(
        plugin_manager => YukiWiki::PluginManager->new(
            $self,
            $self->cfg('modifier_dir_plugin'),
        ),
    );
}

sub plugin_manager { $_[0]->param('plugin_manager') }

sub keyword_reject {
    my $self = shift;
    my $s    = $self->param('mymsg');

    my @reject_words = qw(
        buy-cheap.com
        ultram.online-buy.com
    );

    for ( @reject_words ) {
        if ( $s =~ /\Q$_\E/ ) {
            $self->send_mail_to_admin($self->param('mypage'), "Rejectword: $_");
            sleep(30);
            return 1;
        }
    }
    return 0;
}

# Thanks to Makio Tsukamoto for dc_date.
sub update_rssfile {
    my $self                  = shift;
    my $modifier_rss_link     = $self->cfg('modifier_rss_link');
    my $modifier_rss_timezone = $self->cfg('modifier_rss_timezone');
    my $file_rss              = $self->cfg('file_rss');

    my $rss = YukiWiki::RSS->new(
        version  => '1.0',
        encoding => $self->param('charset'),
    );

    $rss->channel(
        title       => $self->cfg('modifier_rss_title'),
        link        => $modifier_rss_link,
        about       => $self->cfg('modifier_rss_about'),
        description => $self->cfg('modifier_rss_description'),
    );

    my $count = 0;
    for ( split /\n/, $self->database->{$RecentChanges} ) {
        last if $count >= 15;

        # data format.
        /^\- (\d\d\d\d\-\d\d\-\d\d) \(...\) (\d\d:\d\d:\d\d) (\S+)/;

        my $dc_date = "$1T$2$modifier_rss_timezone";
        my $title = &unarmor_name($3);
        my $escaped_title = YukiWiki::Util::escape($title);
        my $link = $modifier_rss_link . '?' . YukiWiki::Util::encode($title);
        my $description = $escaped_title . &escape($self->get_subjectline($title));

        $rss->add_item(
            title       => $escaped_title,
            link        => $link,
            description => $description,
            dc_date     => $dc_date,
        );

        $count++;
    }

    open(FILE, "> $file_rss") or die "($file_rss)";
    print FILE $rss->as_string;
    close(FILE);
}

1;

__END__

=head1 NAME

wiki.cgi - This is YukiWiki, yet another Wiki clone.

=head1 DESCRIPTION

YukiWiki is yet another Wiki clone.

YukiWiki can treat Japanese WikiNames (enclosed with [[ and ]]).
YukiWiki provides 'InterWiki' feature, RDF Site Summary (RSS),
and some embedded commands (such as [[#comment]] to add comments).

=head1 AUTHOR

Hiroshi Yuki <hyuki@hyuki.com> http://www.hyuki.com/yukiwiki/

=head1 LICENSE

Copyright (C) 2000-2006 by Hiroshi Yuki.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
