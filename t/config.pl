#!/usr/bin/perl
use strict;
use warnings;

##############################
#
# You MUST modify following '$modifier_...' variables.
#
my $modifier_mail = 'hyuki@hyuki.com';
my $modifier_url = 'http://www.hyuki.com/';
my $modifier_name = 'Hiroshi Yuki';
my $modifier_dir_data = '.'; # Your data directory (not URL, but DIRECTORY).
my $modifier_url_data = '/static'; # Your data URL (not DIRECTORY, but URL).
my $modifier_rss_title = "YukiWiki $VERSION";
my $modifier_rss_link = 'http://www.hyuki.com/yukiwiki/wiki.cgi';
my $modifier_rss_about = 'http://www.hyuki.com/yukiwiki/rss.xml';
my $modifier_rss_description = 'This is YukiWiki, yet another Wiki clone';
my $modifier_rss_timezone = '+09:00';
##############################
#
# You MAY modify following variables.
#
my $modifier_dbtype = 'YukiWikiDB';
my $modifier_sendmail = '';
# my $modifier_sendmail = '/usr/sbin/sendmail -t -n';
my $modifier_dir_plugin = './plugin';
##############################
#
# You MAY modify following variables.
#
my $file_touch = "$modifier_dir_data/touched.txt";
my $file_resource = "$modifier_dir_data/resource.txt";
my $file_FrontPage = "$modifier_dir_data/frontpage.txt";
my $file_conflict = "$modifier_dir_data/conflict.txt";
my $file_format = "$modifier_dir_data/format.txt";
my $file_rss = "$modifier_dir_data/rss.xml";
my $url_cgi = 'wiki.cgi';
my $url_stylesheet = "$modifier_url_data/wiki.css";
my $icontag = qq(<img src="$modifier_url_data/icon40x40.gif" alt="*" width="40" height="40" />);
my $maxrecent = 50;
my $max_message_length = 500_000; # -1 for unlimited.
my $cols = 80;
my $rows = 20;
##############################
#
# You MAY modify following variables.
# 
my $dataname = "$modifier_dir_data/wiki";
my $infoname = "$modifier_dir_data/info";
my $diffname = "$modifier_dir_data/diff";
my $editchar = '?';
my $subject_delimiter = ' - ';
my $use_autoimg = 1; # automatically convert image URL into <img> tag.
my $use_exists = 0; # If you can use 'exists' method for your DB.
my $use_FixedFrontPage = 0;

my $config = {
    modifier_mail            => $modifier_mail,
    modifier_url             => $modifier_url,
    modifier_name            => $modifier_name,
    modifier_dir_data        => $modifier_dir_data,
    modifier_url_data        => $modifier_url_data,
    modifier_rss_title       => $modifier_rss_title,
    modifier_rss_link        => $modifier_rss_link,
    modifier_rss_about       => $modifier_rss_about,
    modifier_rss_description => $modifier_rss_description,
    modifier_rss_timezone    => $modifier_rss_timezone,
    modifier_dbtype          => $modifier_dbtype,
    modifier_sendmail        => $modifier_sendmail,
    modifier_dir_plugin      => $modifier_dir_plugin,
    file_touch               => $file_touch,
    file_resource            => $file_resource,
    file_FrontPage           => $file_FrontPage,
    file_conflict            => $file_conflict,
    file_format              => $file_format,
    file_rss                 => $file_rss,
    url_cgi                  => $url_cgi,
    url_stylesheet           => $url_stylesheet,
    icontag                  => $icontag,
    maxrecent                => $maxrecent,
    max_message_length       => $max_message_length,
    cols                     => $cols,
    rows                     => $rows,
    dataname                 => $dataname,
    infoname                 => $infoname,
    diffname                 => $diffname,
    editchar                 => $editchar,
    subject_delimiter        => $subject_delimiter,
    use_autoimg              => $use_autoimg,
    use_exists               => $use_exists,
    use_FixedFrontPage       => $use_FixedFrontPage,
};
