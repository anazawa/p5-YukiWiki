package YukiWiki;
#
# wiki.cgi - This is YukiWiki, yet another Wiki clone.
#
# Copyright (C) 2000-2004 by Hiroshi Yuki.
# <hyuki@hyuki.com>
# http://www.hyuki.com/yukiwiki/
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
##############################
# Libraries.
use strict;
use warnings;
use lib qw(lib);
use parent 'CGI::Application';
use CGI::Application::Plugin::Forward;
use CGI::Application::Plugin::ConfigAuto qw/cfg/;
use CGI::Carp;
use Fcntl;
use YukiWiki::RSS;
use YukiWiki::DiffText qw(difftext);
use YukiWiki::DB;
use YukiWiki::PluginManager;
use YukiWiki::Util qw(escape unescape encode decode get_now code_convert);
# Check if the server can use 'AnyDBM_File' or not.
# eval 'use AnyDBM_File';
# my $error_AnyDBM_File = $@;
our $VERSION = '2.1.3';
##############################
#
# You MUST modify following '$modifier_...' variables.
#
#my $modifier_mail = 'hyuki@hyuki.com';
#my $modifier_url = 'http://www.hyuki.com/';
#my $modifier_name = 'Hiroshi Yuki';
#my $modifier_dir_data = '.'; # Your data directory (not URL, but DIRECTORY).
#my $modifier_url_data = '.'; # Your data URL (not DIRECTORY, but URL).
#my $modifier_rss_title = "YukiWiki $VERSION";
#my $modifier_rss_link = 'http://www.hyuki.com/yukiwiki/wiki.cgi';
#my $modifier_rss_about = 'http://www.hyuki.com/yukiwiki/rss.xml';
#my $modifier_rss_description = 'This is YukiWiki, yet another Wiki clone';
#my $modifier_rss_timezone = '+09:00';
##############################
#
# You MAY modify following variables.
#
#my $modifier_dbtype = 'YukiWikiDB';
#my $modifier_sendmail = '';
# my $modifier_sendmail = '/usr/sbin/sendmail -t -n';
#my $modifier_dir_plugin = './plugin';
##############################
#
# You MAY modify following variables.
#
#my $file_touch = "$modifier_dir_data/touched.txt";
#my $file_resource = "$modifier_dir_data/resource.txt";
#my $file_FrontPage = "$modifier_dir_data/frontpage.txt";
#my $file_conflict = "$modifier_dir_data/conflict.txt";
#my $file_format = "$modifier_dir_data/format.txt";
#my $file_rss = "$modifier_dir_data/rss.xml";
my $url_cgi = 'wiki.cgi';
#my $url_stylesheet = "$modifier_url_data/wiki.css";
#my $icontag = qq(<img src="$modifier_url_data/icon40x40.gif" alt="*" width="40" height="40" />);
#my $maxrecent = 50;
#my $max_message_length = 500_000; # -1 for unlimited.
#my $cols = 80;
#my $rows = 20;
##############################
#
# You MAY modify following variables.
# 
#my $dataname = "$modifier_dir_data/wiki";
#my $infoname = "$modifier_dir_data/info";
#my $diffname = "$modifier_dir_data/diff";
my $editchar = '?';
my $subject_delimiter = ' - ';
my $use_autoimg = 1; # automatically convert image URL into <img> tag.
#my $use_exists = 0; # If you can use 'exists' method for your DB.
my $use_FixedFrontPage = 0;
##############################
my $InterWikiName = 'InterWikiName';
my $RecentChanges = 'RecentChanges';
my $AdminChangePassword = 'AdminChangePassword';
my $CompletedSuccessfully = 'CompletedSuccessfully';
my $FrontPage = 'FrontPage';
my $IndexPage = 'IndexPage';
my $SearchPage = 'SearchPage';
my $CreatePage = 'CreatePage';
my $ErrorPage = 'ErrorPage';
my $RssPage = 'RssPage';
my $AdminSpecialPage = 'Admin Special Page'; # must include spaces.
##############################
my $wiki_name = '\b([A-Z][a-z]+([A-Z][a-z]+)+)\b';
my $bracket_name = '\[\[(\S+?)\]\]';
my $embedded_name = '\[\[(#\S+?)\]\]';
my $interwiki_definition = '\[\[(\S+?)\ (\S+?)\]\]';
my $interwiki_name = '([^:]+):([^:].*)';
# Sorry for wierd regex.
my $inline_plugin = '\&amp;(\w+)\((([^()]*(\([^()]*\))?)*)\)';
##############################
my $embed_comment = '[[#comment]]';
my $embed_rcomment = '[[#rcomment]]';
##############################
my $info_ConflictChecker = 'ConflictChecker';
my $info_LastModified = 'LastModified';
my $info_IsFrozen = 'IsFrozen';
my $info_AdminPassword = 'AdminPassword';
##############################
my %fixedpage = (
    $IndexPage => 1,
    $CreatePage => 1,
    $ErrorPage => 1,
    $RssPage => 1,
    $RecentChanges => 1,
    $SearchPage => 1,
    $AdminChangePassword => 1,
    $CompletedSuccessfully => 1,
    $FrontPage => $use_FixedFrontPage,
);
my %form;
my %database;
my %infobase;
my %diffbase;
my %resource;
my %interwiki;
my $plugin_manager;
my $plugin_context = {
    debug => 0,
    database => \%database,
    infobase => \%infobase,
    resource => \%resource,
    form => \%form,
    interwiki => \%interwiki,
    url_cgi => $url_cgi,
};
##############################
my %page_command = (
    $IndexPage => 'index',
    $SearchPage => 'searchform',
    $CreatePage => 'create',
    $RssPage => 'rss',
    $AdminChangePassword => 'adminchangepasswordform',
    $FrontPage => 'FrontPage',
);

sub setup {
    my $self = shift;

    $self->param(
        kanjicode => 'utf8',
        charset   => 'UTF-8',
        lang      => 'ja',
    );

    $self->init_resource;
    # &check_modifiers;
    $self->open_db;
    $self->init_InterWikiName;
    $self->init_plugin;

    $self->mode_param( 'mycmd' );

    $self->start_mode( 'FrontPage' );
    $self->error_mode( 'do_error' );

    $self->run_modes(
        read                    => 'do_read',
        edit                    => 'do_edit',
        adminedit               => 'do_adminedit',
        adminchangepasswordform => 'do_adminchangepasswordform',
        adminchangepassword     => 'do_adminchangepassword',
        write                   => 'do_write',
        index                   => 'do_index',
        searchform              => 'do_searchform',
        search                  => 'do_search',
        create                  => 'do_create',
        createresult            => 'do_createresult',
        FrontPage               => 'do_FrontPage',
        comment                 => 'do_comment',
        rss                     => 'do_rss',
        diff                    => 'do_diff',
    );

    $self->header_add( -charset => $self->param('charset') );

    return;
}

sub kanjicode { $_[0]->param('kanjicode') }
sub charset { $_[0]->param('charset') }
sub lang { $_[0]->param('lang') }

sub cgiapp_prerun {
    my $self = shift;
    my $q = $self->query;

    $self->param( form => \%form );

    my $query_string = $q->param('keywords') || q{}; # <=> $ENV{QUERY_STRING}
    if ($q->param()) {
        foreach my $var ($q->param()) {
            $form{$var} = $q->param($var);
        }
    } else {
        $query_string = $FrontPage;
    }

    my $query = YukiWiki::Util::decode( $query_string || q{} );
    if ($page_command{$query}) {
        $self->prerun_mode( $form{mycmd} = $page_command{$query} );
        $form{mypage} = $query;
    } elsif ($query =~ /^($wiki_name)$/) {
        $self->prerun_mode( $form{mycmd} = 'read' );
        $form{mypage} = $1;
    } elsif ($self->database->{$query}) {
        $self->prerun_mode( $form{mycmd} = 'read' );
        $form{mypage} = $query;
    }

    # mypreview_edit        -> do_edit, with preview.
    # mypreview_adminedit   -> do_adminedit, with preview.
    # mypreview_write       -> do_write, without preview.
    foreach (keys %form) {
        if (/^mypreview_(.*)$/) {
            $self->prerun_mode( $form{mycmd} = $1 );
            $form{mypreview} = 1;
        }
    }

    #
    # $form{mycmd} is frozen here.
    #

    my $kanjicode = $self->param('kanjicode');
    $form{mymsg} = YukiWiki::Util::code_convert(\$form{mymsg}, $kanjicode);
    $form{myname} = YukiWiki::Util::code_convert(\$form{myname}, $kanjicode);

    $self->param(
        mymsg     => $form{mymsg},
        myname    => $form{myname},
        mypage    => $form{mypage},
        mypreview => $form{mypreview},
    );

    $self->add_callback( load_tmpl => 'before_load_tmpl' );
}

sub before_load_tmpl {
    my ( $self, $ht_params, $tmpl_params, $tmpl_file ) = @_;
    $ht_params->{die_on_bad_params} = 0;
    $ht_params->{global_vars} = 1;
    $tmpl_params->{VERSION} = $VERSION;
    $tmpl_params->{lang} = $self->param('lang');
    $tmpl_params->{charset} = $self->param('charset');
}

sub teardown {
    my $self = shift;
    $self->close_db;
}

sub do_read {
    my $self = shift;
    my $mypage = $self->param('mypage');
    my $output = $self->render_header($mypage);
    $output .= $self->render_content($self->database->{$mypage});
    $output .= $self->render_footer($mypage);
    $output;
}

sub do_edit {
    my $self = shift;
    my $resource = $self->param('resource');
    my $database = $self->param('database');
    my $mypage = $self->param('mypage');
    my ($page) = &unarmor_name(&armor_name($mypage));
    my $output = $self->render_header($page);
    if (not $self->is_editable($page)) {
        $output .= $self->render_message($resource->{cantchange});
    } elsif ($self->is_frozen($page)) {
        $output .= $self->render_message($resource->{cantchange});
    } else {
        $output .= $self->render_editform($database->{$page}, $self->get_info($page, $info_ConflictChecker), admin=>0);
    }
    $output .= $self->render_footer($page);
    $output;
}

sub do_adminedit {
    my $self = shift;
    my $resource = $self->param('resource');
    my $database = $self->param('database');
    my $mypage = $self->param('mypage');
    my ($page) = &unarmor_name(&armor_name($mypage));
    my $output = $self->render_header($page);
    if (not $self->is_editable($page)) {
        $output .= $self->render_message($resource->{cantchange});
    } else {
        $output .= $self->render_message($resource->{passwordneeded});
        $output .= $self->render_editform($database->{$page}, $self->get_info($page, $info_ConflictChecker), admin=>1);
    }
    $output .= $self->render_footer($page);
    $output;
}

sub do_adminchangepasswordform {
    my $self = shift;
    my $output = $self->render_header($AdminChangePassword);
    #$output .= &print_passwordform;
    $output .= $self->render_passwordform;
    $output .= $self->render_footer($AdminChangePassword);
    $output;
}

sub do_adminchangepassword {
    my $self = shift;
    my $resource = $self->param('resource');
    my $form = $self->param('form');
    if ($form->{mynewpassword} ne $form->{mynewpassword2}) {
        die $resource->{passwordmismatcherror};
    }
    my ($validpassword_crypt) = $self->get_info($AdminSpecialPage, $info_AdminPassword);
    if ($validpassword_crypt) {
        if (not $self->valid_password($form->{myoldpassword})) {
            $self->send_mail_to_admin(<<"EOD", "AdminChangePassword");
myoldpassword=$form->{myoldpassword}
mynewpassword=$form->{mynewpassword}
mynewpassword2=$form->{mynewpassword2}
EOD
            die $resource->{passworderror};
        }
    }
    my ($sec, $min, $hour, $day, $mon, $year, $weekday) = localtime(time);
    my (@token) = ('0'..'9', 'A'..'Z', 'a'..'z');
    my $salt1 = $token[(time | $$) % scalar(@token)];
    my $salt2 = $token[($sec + $min*60 + $hour*60*60) % scalar(@token)];
    my $crypted = crypt($form->{mynewpassword}, "$salt1$salt2");
    $self->set_info($AdminSpecialPage, $info_AdminPassword, $crypted);

    my $output = $self->render_header($CompletedSuccessfully);
    $output .= $self->render_message($resource->{passwordchanged});
    $output .= $self->render_footer($CompletedSuccessfully);
    $output;
}

sub do_index {
    my $self = shift;
    my $output = $self->render_header($IndexPage);

    my @pages;
    foreach my $page (sort keys %{$self->database}) {
        if ($self->is_editable($page)) {
            # print qq(<li>@{[&get_info($page, $info_IsFrozen)]}</li>);
            # print qq(<li>@{[0 + &is_frozen($page)]}</li>);
            push @pages, {
                page        => $page,
                subjectline => $self->get_subjectline($page),
            };
        }
    }

    $output .= do {
        my $tmpl = $self->load_tmpl;

        $tmpl->param(
            url_cgi => $self->cfg('url_cgi'),
            pages   => \@pages,
        );

        $tmpl->output;
    };

    $output .= $self->render_footer($IndexPage);
    $output;
}

sub do_write {
    my $self     = shift;
    my $resource = $self->param('resource');
    my $database = $self->param('database');
    my $infobase = $self->param('infobase');
    my $form     = $self->param('form');
    my $mypage   = $self->param('mypage');

    if ($self->keyword_reject()) {
        return;
    }

    if ($self->frozen_reject()) {
        return;
    }

    if ($self->length_reject()) {
        return;
    }

    if (not $self->is_editable($mypage)) {
        my $output = $self->render_header($mypage);
        $output .= $self->render_message($resource->{cantchange});
        $output .= $self->render_footer($mypage);
        return $output;
    }

    if (my $output = $self->conflict($mypage, $form->{mymsg})) {
        return $output;
    }

    # Making diff
    if (1) {
        $self->open_diff;
        my @msg1 = split(/\r?\n/, $database->{$mypage});
        my @msg2 = split(/\r?\n/, $form->{mymsg});
        $self->diffbase->{$mypage} = &difftext(\@msg1, \@msg2);
        $self->close_diff;
    }

    if ($form->{mymsg}) {
        $database->{$mypage} = $form->{mymsg};
        $self->send_mail_to_admin($mypage, "Modify");
        $self->set_info($mypage, $info_ConflictChecker, '' . localtime);
        if ($form->{mytouch}) {
            $self->set_info($mypage, $info_LastModified, '' . localtime);
            $self->update_recent_changes;
        }
        $self->set_info($mypage, $info_IsFrozen, 0 + $form->{myfrozen});
        my $output = $self->render_header($CompletedSuccessfully);
        $output .= $self->render_message($resource->{saved});
        $output .= $self->render_content(
            "$resource->{continuereading} @{[&armor_name($mypage)]}"
        );
        $output .= $self->render_footer($CompletedSuccessfully);
        return $output;
    } else {
        $self->send_mail_to_admin($mypage, "Delete");
        delete $database->{$mypage};
        delete $infobase->{$mypage};
        if ($form->{mytouch}) {
            $self->update_recent_changes;
        }
        my $output = $self->render_header($mypage);
        $output .= $self->render_message($resource->{deleted});
        $output .= $self->render_footer($mypage);
        return $output;
    }
}

sub do_searchform {
    my $self = shift;;
    my $output = $self->render_header($SearchPage);
    $output .= $self->render_searchform("");
    $output .= $self->render_footer($SearchPage);
    $output;
}

sub do_search {
    my $self = shift;
    my $word = YukiWiki::Util::escape($form{mymsg});
    my $output = $self->render_header($SearchPage);
    $output .= $self->render_searchform($word);

    my @pages;
    foreach my $page (sort keys %database) {
        next if $page =~ /^$RecentChanges$/;
        if ($database{$page} =~ /\Q$form{mymsg}\E/ or $page =~ /\Q$form{mymsg}\E/) {
            push @pages, {
                page        => $page,
                subjectline => $self->get_subjectline($page),
            };
        }
    }

    if ( @pages ) {
        my $tmpl = $self->load_tmpl;
        $tmpl->param(
            url_cgi => $self->cfg('url_cgi'),
            pages   => \@pages,
        );
        $output .= $tmpl->output;
    }
    else {
        $output .= $self->render_message($self->resource->{notfound});
    }

    $output .= $self->render_footer($SearchPage);
    $output;
}

sub do_create {
    my $self = shift;
    my $resource = $self->param('resource');
    my $output = $self->render_header($CreatePage);

    $output .= do {
        my $tmpl = $self->load_tmpl;
        $tmpl->param(
            url_cgi      => $self->cfg('url_cgi'),
            newpagename  => $resource->{newpagename},
            createbutton => $resource->{createbutton},
        );
        $tmpl->output;
    };

    $output .= $self->render_footer($CreatePage);
    $output;
}

sub do_FrontPage {
    my $self = shift;
    if ($fixedpage{$FrontPage}) {
        my $file_FrontPage = $self->cfg('file_FrontPage');
        open(FILE, $file_FrontPage) or die "($file_FrontPage)";
        my $content = join('', <FILE>);
        YukiWiki::Util::code_convert(\$content, $self->kanjicode);
        close(FILE);
        my $output = $self->render_header($FrontPage);
        $output .= $self->render_content($content);
        $output .= $self->render_footer($FrontPage);
        return $output;
    } else {
        $form{mycmd} = 'read';
        $self->param( mypage => $form{mypage} = $FrontPage );
        return $self->forward( 'read' );
    }
}

sub do_error {
    my ( $self, $msg ) = @_;
    my $output = $self->render_header($ErrorPage);
    $output .= qq(<p><strong class="error">$msg</strong></p>);
    $output .= $self->render_plugin_log;
    $output .= $self->render_footer($ErrorPage);
    $output;
}

sub render_header {
    my ($self, $page) = @_;
    my $tmpl = $self->load_tmpl('head.html');
    my $bodyclass = "normal";
    my $editable = 0;
    my $admineditable = 0;
    if ($self->is_frozen($page) and $form{mycmd} =~ /^(read|write)$/) {
        $editable = 0;
        $admineditable = 1;
        $bodyclass = "frozen";
    } elsif ($self->is_editable($page) and $form{mycmd} =~ /^(read|write)$/) {
        $admineditable = 1;
        $editable = 1;
    } else {
        $editable = 0;
    }
    my $cookedpage = YukiWiki::Util::encode($page);
    my $escapedpage = YukiWiki::Util::escape($page);
    my $resource = $self->param('resource');

    $tmpl->param(
        IndexPage            => $IndexPage,
        CreatePage           => $CreatePage,
        SearchPage           => $SearchPage,
        FrontPage            => $FrontPage,
        RecentChanges        => $RecentChanges,
        page                 => $page,
        subjectline          => $self->get_subjectline($page),
        escapedpage          => $escapedpage,
        bodyclass            => $bodyclass,
        admineditable        => $admineditable,
        cookedpage           => $cookedpage,
        editable             => $editable,
        url_cgi              => $self->cfg('url_cgi'),
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

    $tmpl->output;

}

sub render_footer {
    my $self = shift;
    my $page = shift;
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
    my ($self, $rawcontent) = @_;
    return $self->text_to_html($rawcontent, toc=>1);
}

sub text_to_html {
    my ($self, $txt, %option) = @_;
    my (@txt) = split(/\r?\n/, $txt);
    my (@toc);
    my $verbatim;
    my $tocnum = 0;
    my (@saved, @result);
    my $inline = sub { $self->inline(@_) }; # alias
    unshift(@saved, "</p>");
    push(@result, "<p>");
    foreach (@txt) {
        chomp;

        # verbatim.
        if ($verbatim->{func}) {
            if (/^\Q$verbatim->{done}\E$/) {
                undef $verbatim;
                push(@result, splice(@saved));
            } else {
                push(@result, $verbatim->{func}->($_));
            }
            next;
        }

        # non-verbatim follows.
        push(@result, shift(@saved)) if (@saved and $saved[0] eq '</pre>' and /^[^ \t]/);
        if (/^(\*{1,3})(.+)/) {
            # $hn = 'h2', 'h3' or 'h4'
            my $hn = "h" . (length($1) + 1);
            push(@toc, '-' x length($1) . qq( <a href="#i$tocnum">)
                . &remove_tag($inline->($2)) . qq(</a>\n));
            push(@result, splice(@saved), qq(<$hn><a name="i$tocnum"> </a>)
                . $inline->($2) . qq(</$hn>));
            $tocnum++;
        } elsif (/^(-{2,3})\($/) {
            if ($& eq '--(') {
                $verbatim = { func => $inline, done => '--)', class => 'verbatim-soft' };
            } else {
                $verbatim = { func => \&escape, done => '---)', class => 'verbatim-hard' };
            }
            &back_push('pre', 1, \@saved, \@result, " class='$verbatim->{class}'");
        } elsif (/^----/) {
            push(@result, splice(@saved), '<hr>');
        } elsif (/^(-{1,3})(.+)/) {
            &back_push('ul', length($1), \@saved, \@result);
            push(@result, '<li>' . $inline->($2) . '</li>');
        } elsif (/^:([^:]+):(.+)/) {
            &back_push('dl', 1, \@saved, \@result);
            push(@result, '<dt>' . $inline->($1) . '</dt>', '<dd>'
                . $inline->($2) . '</dd>');
        } elsif (/^(>{1,3})(.+)/) {
            &back_push('blockquote', length($1), \@saved, \@result);
            push(@result, $inline->($2));
        } elsif (/^$/) {
            push(@result, splice(@saved));
            unshift(@saved, "</p>");
            push(@result, "<p>");
        } elsif (/^(\s+.*)$/) {
            &back_push('pre', 1, \@saved, \@result);
            push(@result, &escape($1)); # Not &inline, but &escape
        } elsif (/^\,(.*?)[\x0D\x0A]*$/) {
            &back_push('table', 1, \@saved, \@result, ' border="1"');
            #######
            # This part is taken from Mr. Ohzaki's Perl Memo and Makio Tsukamoto's WalWiki.
            # XXXXX
            my $tmp = "$1,";
            my @value = map {/^"(.*)"$/ ? scalar($_ = $1, s/""/"/g, $_) : $_} ($tmp =~ /("[^"]*(?:""[^"]*)*"|[^,]*),/g);
            my @align = map {(s/^\s+//) ? ((s/\s+$//) ? ' align="center"' : ' align="right"') : ''} @value;
            my @colspan = map {($_ eq '==') ? 0 : 1} @value;
            for (my $i = 0; $i < @value; $i++) {
                if ($colspan[$i]) {
                    while ($i + $colspan[$i] < @value and $value[$i + $colspan[$i]] eq '==') {
                        $colspan[$i]++;
                    }
                    $colspan[$i] = ($colspan[$i] > 1) ? sprintf(' colspan="%d"', $colspan[$i]) : '';
                    $value[$i] = sprintf('<td%s%s>%s</td>', $align[$i],
                        $colspan[$i], $inline->($value[$i]));
                } else {
                    $value[$i] = '';
                }
            }
            push(@result, join('', '<tr>', @value, '</tr>'));
            # XXXXX
            #######
        } elsif (/^\#(\w+)(\((.*)\))?/) {
            # BlockPlugin.
            my $original_line = $_;
            my $plugin_name = $1;
            my $argument = YukiWiki::Util::escape($3);
            my $result = $self->plugin_manager->call($plugin_name, 'block', $argument);
            if (defined($result)) {
                push(@result, splice(@saved));
            } else {
                $result = $original_line;
            }
            push(@result, $result);
        } else {
            push(@result, $inline->($_));
        }
    }
    push(@result, splice(@saved));

    if ($option{toc}) {
        # Convert @toc (table of contents) to HTML.
        # This part is taken from Makio Tsukamoto's WalWiki.
        my (@tocsaved, @tocresult);
        foreach (@toc) {
            if (/^(-{1,3})(.*)/) {
                &back_push('ul', length($1), \@tocsaved, \@tocresult);
                push(@tocresult, '<li>' . $2 . '</li>');
            }
        }
        push(@tocresult, splice(@tocsaved));

        # Insert "table of contents".
        if (@tocresult) {
            my $resource = $self->resource;
            unshift(@tocresult, qq(<h2>$resource->{table_of_contents}</h2>));
        }

        return join("\n", @tocresult, @result);
    } else {
        return join("\n", @result);
    }
}

sub back_push { # function
    my ($tag, $level, $savedref, $resultref, $attr) = @_;
    $attr ||= q{};
    while (@$savedref > $level) {
        push(@$resultref, shift(@$savedref));
    }
    if ($savedref->[0] and $savedref->[0] ne "</$tag>") {
        push(@$resultref, splice(@$savedref));
    }
    while (@$savedref < $level) {
        unshift(@$savedref, "</$tag>");
        push(@$resultref, "<$tag$attr>");
    }
}

sub remove_tag { # function
    my ($line) = @_;
    $line =~ s|\<\/?[A-Za-z][^>]*?\>||g;
    return $line;
}

sub inline {
    my ($self, $line) = @_;
    $line = YukiWiki::Util::escape($line);
    $line =~ s|'''([^']+?)'''|<i>$1</i>|g;  # Italic
    $line =~ s|''([^']+?)''|<b>$1</b>|g;    # Bold
    $line =~ s|(\d\d\d\d-\d\d-\d\d \(\w\w\w\) \d\d:\d\d:\d\d)|<span class="date">$1</span>|g;   # Date
    $line =~ s!
                (
                    ((mailto|http|https|ftp):([^\x00-\x20()<>\x7F-\xFF])*)  # Direct http://...
                        |
                    ($bracket_name)             # [[likethis]], [[#comment]], [[Friend:remotelink]]
                        |
                    ($interwiki_definition)     # [[Friend http://somewhere/?q=sjis($1)]]
                        |
                    ($wiki_name)                # LocalLinkLikeThis
                        |
                    ($inline_plugin)            # &user_defined_plugin(123,hello)
                )
            !
                $self->make_link($1)
            !gex;
    return $line;
}

sub make_link {
    my ($self, $chunk) = @_;
    if ($chunk =~ /^(http|https|ftp):/) {
        if ($use_autoimg and $chunk =~ /\.(gif|png|jpeg|jpg)$/) {
            return qq(<a href="$chunk"><img src="$chunk"></a>);
        } else {
            return qq(<a href="$chunk">$chunk</a>);
        }
    } elsif ($chunk =~ /^(mailto):(.*)/) {
        return qq(<a href="$chunk">$2</a>);
    } elsif ($chunk =~ /^$interwiki_definition$/) {
        return qq(<span class="InterWiki">$chunk</span>);
    } elsif ($chunk =~ /^$embedded_name$/) {
        return $self->embedded_to_html($chunk);
    } elsif ($chunk =~ /^$inline_plugin$/) {
        # InlinePlugin.
        my $plugin_name = $1;
        my $argument = $2;
        my $result = $plugin_manager->call($plugin_name, 'inline', $argument);
        if (defined($result)) {
            return $result;
        } else {
            return $chunk;
        }
    } else {
        $chunk = &unarmor_name($chunk);
        $chunk = &unescape($chunk); # To treat '&' or '>' or '<' correctly.
        my $cookedchunk = YukiWiki::Util::encode($chunk);
        my $escapedchunk = YukiWiki::Util::escape($chunk);
        if ($chunk =~ /^$interwiki_name$/) {
            my ($intername, $localname) = ($1, $2);
            my $remoteurl = $interwiki{$intername};
            if ($remoteurl =~ /^(http|https|ftp):\/\//) { # Check if scheme if valid.
                $remoteurl =~ s/\b(euc|sjis|ykwk|asis)\(\$1\)/$self->interwiki_convert($1, $localname)/e;
                return qq(<a href="$remoteurl">$escapedchunk</a>);
            } else {
                return $escapedchunk;
            }
        } elsif ($database{$chunk}) {
            my $subject = &escape($self->get_subjectline($chunk, delimiter => ''));
            return qq(<a title="$subject" href="$url_cgi?$cookedchunk">$escapedchunk</a>);
        } elsif ($page_command{$chunk}) {
            return qq(<a title="$escapedchunk" href="$url_cgi?$cookedchunk">$escapedchunk</a>);
        } else {
            return qq($escapedchunk<a title="$resource{editthispage}" class="editlink" href="$url_cgi?mycmd=edit&amp;mypage=$cookedchunk">$editchar</a>);
        }
    }
}

sub render_message {
    my ($self, $msg) = @_;
    return qq(<p><strong>$msg</strong></p>);
}

sub update_recent_changes {
    my $self = shift;
    my $mypage = $self->param('mypage');
    my $database = $self->param('database');
    my $update = join(' ',
        '-',
        &get_now,
        &armor_name($mypage),
        $self->get_subjectline($mypage),
    );
    my @oldupdates = split(/\r?\n/, $database->{$RecentChanges});
    my @updates;
    foreach (@oldupdates) {
        /^\- \d\d\d\d\-\d\d\-\d\d \(...\) \d\d:\d\d:\d\d (\S+)/;    # date format.
        my $name = &unarmor_name($1);
        if ($self->is_exist_page($name) and ($name ne $mypage)) {
            push(@updates, $_);
        }
    }
    if ($self->is_exist_page($mypage)) {
        unshift(@updates, $update);
    }
    splice(@updates, $self->cfg('maxrecent') + 1);
    $database->{$RecentChanges} = join("\n", @updates);
    if (my $file_touch = $self->cfg('file_touch')) {
        open(FILE, "> $file_touch");
        print FILE localtime() . "\n";
        close(FILE);
    }
    if ($self->cfg('file_rss')) {
        $self->update_rssfile;
    }
}

sub get_subjectline {
    my ($self, $page, %option) = @_;
    if (not $self->is_editable($page)) {
        return "";
    } else {
        # Delimiter check.
        my $delim = $subject_delimiter;
        if (defined($option{delimiter})) {
            $delim = $option{delimiter};
        }

        # Get the subject of the page.
        my $subject = $database{$page};
        $subject =~ s/\r?\n.*//s;
        return "$delim$subject";
    }
}

sub send_mail_to_admin {
    my ($self, $page, $mode) = @_;
    my $modifier_sendmail = $self->cfg('modifier_sendmail');
    return unless $modifier_sendmail;
    my $remote_addr = $self->query->remote_addr;
    my $remote_host = $self->query->remote_host;
    my $database = $self->param('database');
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

sub open_db {
    my $self = shift;
    my $modifier_dbtype = $self->cfg('modifier_dbtype');
    my $dataname = $self->cfg('dataname');
    my $infoname = $self->cfg('infoname');

    if ($modifier_dbtype eq 'dbmopen') {
        dbmopen(%database, $dataname, 0666) or croak("(dbmopen) $dataname");
        dbmopen(%infobase, $infoname, 0666) or croak("(dbmopen) $infoname");
    } elsif ($modifier_dbtype eq 'AnyDBM_File') {
        tie(%database, "AnyDBM_File", $dataname, O_RDWR|O_CREAT, 0666)
            or croak("(tie AnyDBM_File) $dataname");
        tie(%infobase, "AnyDBM_File", $infoname, O_RDWR|O_CREAT, 0666)
            or croak("(tie AnyDBM_File) $infoname");
    } else {
        tie(%database, "YukiWiki::DB", $dataname)
            or croak("(tie YukiWiki::DB) $dataname");
        tie(%infobase, "YukiWiki::DB", $infoname)
            or croak("(tie YukiWiki::DB) $infoname");
    }

    $self->param(
        database => \%database,
        infobase => \%infobase,
    );

}

sub close_db {
    my $self = shift;
    my $modifier_dbtype = $self->cfg('modifier_dbtype');

    if ($modifier_dbtype eq 'dbmopen') {
        dbmclose(%database);
        dbmclose(%infobase);
    } elsif ($modifier_dbtype eq 'AnyDBM_File') {
        untie(%database);
        untie(%infobase);
    } else {
        untie(%database);
        untie(%infobase);
    }

    $self->delete('database');
    $self->delete('infobase');
}

sub database { $_[0]->param('database') }
sub infobase { $_[0]->param('infobase') }

sub open_diff {
    my $self = shift;
    my $modifier_dbtype = $self->cfg('modifier_dbtype');
    my $diffname = $self->cfg('diffname');
    if ($modifier_dbtype eq 'dbmopen') {
        dbmopen(%diffbase, $diffname, 0666) or die "(dbmopen) $diffname";
    } elsif ($modifier_dbtype eq 'AnyDBM_File') {
        tie(%diffbase, "AnyDBM_File", $diffname, O_RDWR|O_CREAT, 0666) or die "(tie AnyDBM_File) $diffname";
    } else {
        tie(%diffbase, "YukiWiki::DB", $diffname) or
        die "(tie YukiWiki::DB) $diffname";
    }
    $self->param( diffbase => \%diffbase );
}

sub close_diff {
    my $self = shift;
    my $modifier_dbtype = $self->cfg('modifier_dbtype');
    if ($modifier_dbtype eq 'dbmopen') {
        dbmclose(%diffbase);
    } elsif ($modifier_dbtype eq 'AnyDBM_File') {
        untie(%diffbase);
    } else {
        untie(%diffbase);
    }
    $self->delete( 'diffbase' );
}

sub diffbase { $_[0]->param('diffbase') }

sub render_searchform {
    my $self = shift;
    my $word = shift;
    my $tmpl = $self->load_tmpl('searchform.html');

    $tmpl->param(
        url_cgi      => $self->cfg('url_cgi'),
        word         => $word,
        searchbutton => $self->resource->{searchbutton},
    );

    $tmpl->output;
}

sub render_editform {
    my ($self, $mymsg, $conflictchecker, %mode) = @_;
    my $frozen = $self->is_frozen($form{mypage});
    my $resource = $self->param('resource');

    my $editform;

    if ($form{mypreview}) {
        if ($form{mymsg}) {
            unless ($mode{conflict}) {
                $editform .= qq(<h3>$resource->{previewtitle}</h3>\n);
                $editform .= qq($resource->{previewnotice}\n);
                $editform .= qq(<div class="preview">\n);
                $editform .= $self->render_content($form{mymsg});
                $editform .= qq(</div>\n);
            }
        } else {
            $editform .= qq($resource->{previewempty});
        }
        $mymsg = YukiWiki::Util::escape($form{mymsg});
    } else {
        $mymsg = YukiWiki::Util::escape($mymsg);
    }

    my $edit = $mode{admin} ? 'adminedit' : 'edit';
    my $escapedmypage = YukiWiki::Util::escape($form{mypage});
    my $escapedmypassword = YukiWiki::Util::escape($form{mypassword});

    my $file_format;
    unless ($mode{conflict}) {
        # Show the format rule.
        my $path = $self->cfg('file_format');
        open(FILE, $path) or die "($path)";
        my $content = join('', <FILE>);
        YukiWiki::Util::code_convert(\$content, $self->kanjicode);
        close(FILE);
        $file_format = $self->text_to_html($content, toc=>0);
    }

    my $plugin_usage;
    unless ($mode{conflict}) {
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
        $plugin_usage = $plugin_usage_tmpl->output;
        YukiWiki::Util::code_convert(\$plugin_usage, $self->kanjicode);
        $plugin_usage = $self->text_to_html($plugin_usage, toc=>0);
    }

    my $tmpl = $self->load_tmpl('editform.html');

    $tmpl->param(
        url_cgi           => $self->cfg('url_cgi'),
        cols              => $self->cfg('cols'),
        rows              => $self->cfg('rows'),
        admin             => $mode{admin},
        conflict          => $mode{conflict},
        escapedmypassword => $escapedmypassword,
        conflictchecker   => $conflictchecker,
        escapedmypage     => $escapedmypage,
        mymsg             => $mymsg,
        frozen            => $frozen,
        edit              => $edit,
        file_format       => $file_format,
        plugin_usage      => $plugin_usage,
        frozenpassword    => $resource->{frozenpassword},
        frozenbutton      => $resource->{frozenbutton},
        notfrozenbutton   => $resource->{notfrozenbutton},
        touch             => $resource->{touch},
        previewbutton     => $resource->{previewbutton},
        savebutton        => $resource->{savebutton},

    );

    $editform .= $tmpl->output;

    $editform;
}

sub render_passwordform {
    my $self     = shift;
    my $tmpl     = $self->load_tmpl('passwordform.html');
    my $resource = $self->param('resource');

    $tmpl->param(
        url_cgi              => $self->cfg('url_cgi'),
        oldpassword          => $resource->{oldpassword},
        newpassword          => $resource->{newpassword},
        newpassword2         => $resource->{newpassword2},
        changepasswordbutton => $resource->{changepasswordbutton},
    );

    $tmpl->output;
}

sub is_editable {
    my ($self, $page) = @_;
    if (&is_bracket_name($page)) {
        return 0;
    } elsif ($fixedpage{$page}) {
        return 0;
    } elsif ($page =~ /\s/) {
        return 0;
    } elsif ($page =~ /^\#/) {
        return 0;
    } elsif ($page =~ /^$interwiki_name$/) {
        return 0;
    } elsif (not $page) {
        return 0;
    } else {
        return 1;
    }
}

# armor_name:
#   WikiName -> WikiName
#   not_wiki_name -> [[not_wiki_name]]
sub armor_name {
    my ($name) = @_;
    if ($name =~ /^$wiki_name$/) {
        return $name;
    } else {
        return "[[$name]]";
    }
}

# unarmor_name:
#   [[bracket_name]] -> bracket_name
#   WikiName -> WikiName
sub unarmor_name {
    my ($name) = @_;
    if ($name =~ /^$bracket_name$/) {
        return $1;
    } else {
        return $name;
    }
}

sub is_bracket_name {
    my ($name) = @_;
    if ($name =~ /^$bracket_name$/) {
        return 1;
    } else {
        return 0;
    }
}

sub init_resource {
    my $self = shift;
    my $kanjicode = $self->param('kanjicode');
    $self->param( resource => \%resource );
    open(FILE, $self->cfg('file_resource')) or croak("(resource)");
    while (<FILE>) {
        chomp;
        next if /^#/;
        my ($key, $value) = split(/=/, $_, 2);
        $resource{$key} = YukiWiki::Util::code_convert(\$value, $kanjicode);
    }
    close(FILE);
}

sub resource { $_[0]->param('resource') }

sub conflict {
    my ($self, $page, $rawmsg) = @_;
    my $form = $self->param('form');
    if ($form->{myConflictChecker} eq $self->get_info($page, $info_ConflictChecker)) {
        return 0;
    }
    open(FILE, $self->cfg('file_conflict')) or die "(conflict)";
    my $content = join('', <FILE>);
    YukiWiki::Util::code_convert(\$content, $self->kanjicode);
    close(FILE);
    my $output = $self->render_header($page);
    $output .= $self->render_content($content);
    $output .= $self->render_editform($rawmsg, $form->{myConflictChecker}, frozen=>0, conflict=>1);
    $output .= $self->render_footer($page);
    return $output;
}

# [[YukiWiki http://www.hyuki.com/yukiwiki/wiki.cgi?euc($1)]]
sub init_InterWikiName {
    my $self = shift;
    my $content = $self->database->{$InterWikiName} || q{};
    while ($content =~ /\[\[(\S+) +(\S+)\]\]/g) {
        my ($name, $url) = ($1, $2);
        $interwiki{$name} = $url;
    }
}

sub interwiki_convert {
    my ($self, $type, $localname) = @_;
    if ($type eq 'sjis' or $type eq 'euc') {
        YukiWiki::Util::code_convert(\$localname, $type);
        return &encode($localname);
    } elsif ($type eq 'ykwk') {
        # for YukiWiki1
        if ($localname =~ /^$wiki_name$/) {
            return $localname;
        } else {
            YukiWiki::Util::code_convert(\$localname, 'sjis');
            return &encode("[[" . $localname . "]]");
        }
    } elsif ($type eq 'asis') {
        return $localname;
    } else {
        return $localname;
    }
}

sub get_info {
    my ($self, $page, $key) = @_;
    my $info = $self->infobase->{$page} || q{};
    my %info = map { split(/=/, $_, 2) } split(/\n/, $info);
    return $info{$key};
}

sub set_info {
    my ($self, $page, $key, $value) = @_;
    my $infobase = $self->param('infobase');
    my %info = map { split(/=/, $_, 2) } split(/\n/, $infobase->{$page});
    $info{$key} = $value;
    my $s = '';
    for (keys %info) {
        $s .= "$_=$info{$_}\n";
    }
    $infobase->{$page} = $s;
}

sub frozen_reject {
    my $self = shift;
    my $form = $self->param('form');
    my ($isfrozen) = $self->get_info($form->{mypage}, $info_IsFrozen);
    my ($willbefrozen) = $form->{myfrozen};
    if (not $isfrozen and not $willbefrozen) {
        # You need no check.
        return 0;
    } elsif ($self->valid_password($form->{mypassword})) {
        # You are admin.
        return 0;
    } else {
        die $self->resource->{passworderror};
        return 1;
    }
}

sub length_reject {
    my $self = shift;
    my $max_message_length = $self->cfg('max_message_length');
    if ($max_message_length < 0) {
        return 0;
    }
    if ($max_message_length < length($self->param('form')->{mymsg})) {
        die $self->resource->{toolongpost} . $max_message_length;
        return 1;
    }
    return 0;
}

sub valid_password {
    my ($self, $givenpassword) = @_;
    my ($validpassword_crypt) = $self->get_info($AdminSpecialPage, $info_AdminPassword);
    if (crypt($givenpassword, $validpassword_crypt) eq $validpassword_crypt) {
        return 1;
    } else {
        return 0;
    }
}

sub is_frozen {
    my ($self, $page) = @_;
    if ($self->get_info($page, $info_IsFrozen)) {
        return 1;
    } else {
        return 0;
    }
}

sub do_comment {
    my $self = shift;
    my ($content) = $self->database->{$form{mypage}};
    my $datestr = YukiWiki::Util::get_now();
    my $namestr = $form{myname} ? " ''[[$form{myname}]]'' : " : " ";
    if ($content =~ s/(^|\n)(\Q$embed_comment\E)/$1- $datestr$namestr$form{mymsg}\n$2/) {
        ;
    } else {
        $content =~ s/(^|\n)(\Q$embed_rcomment\E)/$1$2\n- $datestr$namestr$form{mymsg}/;
    }
    if ($form{mymsg}) {
        $form{mymsg} = $content;
        $form{mytouch} = 'on';
        return $self->forward( 'write' );
    } else {
        $form{mycmd} = 'read';
        return $self->forward( 'read' );
    }
}

sub embedded_to_html {
    my ($self, $embedded) = @_;
    my $escapedmypage = YukiWiki::Util::escape($form{mypage});
    if ($embedded eq $embed_comment or $embedded eq $embed_rcomment) {
        my $conflictchecker = $self->get_info($form{mypage}, $info_ConflictChecker);
        my $resource = $self->param('resource');
        return do {
            my $tmpl = $self->load_tmpl('commentform.html');
            $tmpl->param(
                url_cgi         => $self->cfg('url_cgi'),
                escapedmypage   => $escapedmypage,
                conflictchecker => $conflictchecker,
                yourname        => $resource->{yourname},
                commentbutton   => $resource->{commentbutton},
            );
            $tmpl->output; 
        };
    } else {
        return $embedded;
    }
}

sub do_diff {
    my $self = shift;
    my $resource = $self->param('resource');
    my $form = $self->param('form');
    if (not $self->is_editable($form->{mypage})) {
        return $self->forward( 'read' );
    }
    $self->open_diff;
    my $title = $form->{mypage};
    my $output = $self->render_header($title);
    $_ = YukiWiki::Util::escape($self->diffbase->{$form->{mypage}});
    $self->close_diff;
    $output .= qq(<h3>$resource->{difftitle}</h3>);
    $output .= qq($resource->{diffnotice});
    $output .= qq(<pre class="diff">);
    foreach (split(/\n/, $_)) {
        if (/^\+(.*)/) {
            $output .= qq(<b class="added">$1</b>\n);
        } elsif (/^\-(.*)/) {
            $output .= qq(<s class="deleted">$1</s>\n);
        } elsif (/^\=(.*)/) {
            $output .= qq(<span class="same">$1</span>\n);
        } else {
            $output .= qq|??? $_\n|;
        }
    }
    $output .= qq(</pre>);
    $output .= qq(<hr>);
    $output .= $self->render_footer($title);
    $output;
}

sub do_rss {
    my $self = shift;
    if ($self->cfg('file_rss')) {
        $self->header_add(
            -status   => '301 Moved Permanently',
            -location => $self->cfg('modifier_rss_about'),
            -type     => q{},
        );
    }
}

sub is_exist_page {
    my ($self, $name) = @_;
    if ($self->cfg('use_exists')) {
        return exists($self->database->{$name});
    } else {
        return $self->database->{$name};
    }
}

# sub check_modifiers {
#     if ($error_AnyDBM_File and $modifier_dbtype eq 'AnyDBM_File') {
#         &print_error($resource{anydbmfileerror});
#     }
# }

# Initialize plugins.
sub init_plugin {
    my $self = shift;
    my $modifier_dir_plugin = $self->cfg('modifier_dir_plugin');
    $plugin_manager = new YukiWiki::PluginManager($plugin_context, $modifier_dir_plugin);
    $self->param( plugin_manager => $plugin_manager );
}

sub plugin_manager { $_[0]->param('plugin_manager') }

sub print_plugin_log {
    if ($plugin_context->{debug}) {
        print "<pre>(print_plugin_log)\n", join("\n", @{$plugin_manager->{log}}), "</pre>";
    }
}

sub render_plugin_log {
    my $self = shift;
    if ($plugin_context->{debug}) {
        my $log = $self->plugin_manager->{log};
        return "<pre>(print_plugin_log)\n" . join("\n", @{$log}) . "</pre>";
    }
    return q{};
}

sub keyword_reject {
    my $self = shift;
    my $form = $self->param('form');
    my $s = $form->{mymsg};
    my @reject_words = qw(
buy-cheap.com
ultram.online-buy.com
    );
    for (@reject_words) {
        if ($s =~ /\Q$_\E/) {
            $self->send_mail_to_admin($form->{mypage}, "Rejectword: $_");
            sleep(30);
            return 1;
        }
    }
    return 0;
}

# Thanks to Makio Tsukamoto for dc_date.
sub update_rssfile {
    my $self = shift;
    my $modifier_rss_link = $self->cfg('modifier_rss_link');
    my $modifier_rss_timezone = $self->cfg('modifier_rss_timezone');
    my $rss = new YukiWiki::RSS(
        version => '1.0',
        encoding => $self->param('charset'),
    );
    $rss->channel(
        title => $self->cfg('modifier_rss_title'),
        link  => $modifier_rss_link,
        about  => $self->cfg('modifier_rss_about'),
        description => $self->cfg('modifier_rss_description'),
    );
    my $recentchanges = $self->database->{$RecentChanges};
    my $count = 0;
    foreach (split(/\n/, $recentchanges)) {
        last if ($count >= 15);
        /^\- (\d\d\d\d\-\d\d\-\d\d) \(...\) (\d\d:\d\d:\d\d) (\S+)/;    # date format.
        my $dc_date = "$1T$2$modifier_rss_timezone";
        my $title = &unarmor_name($3);
        my $escaped_title = YukiWiki::Util::escape($title);
        my $link = $modifier_rss_link . '?' . YukiWiki::Util::encode($title);
        my $description = $escaped_title . &escape($self->get_subjectline($title));
        $rss->add_item(
            title => $escaped_title,
            link  => $link,
            description => $description,
            dc_date => $dc_date,
        );
        $count++;
    }
    my $file_rss = $self->cfg('file_rss');
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
