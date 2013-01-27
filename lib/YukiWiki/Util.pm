package YukiWiki::Util;
use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(
    escape unescape
    decode encode
    get_now
    code_convert
);

sub escape {
    my $s = shift;
    $s =~ s|\r\n|\n|g;
    $s =~ s|\&|&amp;|g;
    $s =~ s|<|&lt;|g;
    $s =~ s|>|&gt;|g;
    $s =~ s|"|&quot;|g;
    return $s;
}

sub unescape {
    my $s = shift;
    # $s =~ s|\n|\r\n|g;
    $s =~ s|\&amp;|\&|g;
    $s =~ s|\&lt;|\<|g;
    $s =~ s|\&gt;|\>|g;
    $s =~ s|\&quot;|\"|g;
    return $s;
}

sub decode {
    my ($s) = @_;
    $s =~ tr/+/ /;
    $s =~ s/%([A-Fa-f0-9][A-Fa-f0-9])/pack("C", hex($1))/eg;
    return $s;
}

# Thanks to WalWiki for [better encode].
sub encode {
    my ($encoded) = @_;
    $encoded =~ s/(\W)/'%' . unpack('H2', $1)/eg;
    return $encoded;
}

sub get_now {
    my (@week) = qw(Sun Mon Tue Wed Thu Fri Sat);
    my ($sec, $min, $hour, $day, $mon, $year, $weekday) = localtime(time);
    $year += 1900;
    $mon++;
    $mon = "0$mon" if $mon < 10;
    $day = "0$day" if $day < 10;
    $hour = "0$hour" if $hour < 10;
    $min = "0$min" if $min < 10;
    $sec = "0$sec" if $sec < 10;
    $weekday = $week[$weekday];
    return "$year-$mon-$day ($weekday) $hour:$min:$sec";
}

sub code_convert {
    my ($contentref, $kanjicode) = @_;
    &Jcode::convert($contentref, $kanjicode);
    return $$contentref;
}

1;
