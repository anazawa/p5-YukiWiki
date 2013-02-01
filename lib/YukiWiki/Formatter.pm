package YukiWiki::Formatter;
use strict;
use warnings;
use YukiWiki::Util;

my $wiki_name            = qr{\b([A-Z][a-z]+([A-Z][a-z]+)+)\b};
my $bracket_name         = qr{\[\[(\S+?)\]\]};
my $embedded_name        = qr{\[\[(#\S+?)\]\]};
my $interwiki_definition = qr{\[\[(\S+?)\ (\S+?)\]\]};
my $interwiki_name       = qr{([^:]+):([^:].*)};
# Sorry for wierd regex.
my $inline_plugin = qr{\&amp;(\w+)\((([^()]*(\([^()]*\))?)*)\)};

sub new {
    my $class = shift;
    bless { @_ }, $class;
}

sub context { $_[0]->{context} }

sub use_autoimg { $_[0]->{use_autoimg} }

sub editchar { $_[0]->{editchar} }

sub plugin_manager { $_[0]->{plugin_manager} }

sub resource { $_[0]->{resource} }

sub interwiki { $_[0]->{interwiki} }

sub as_string {
    my $self   = shift;
    my $txt    = $self->{txt};
    my %option = %{ $self->{option} };
    my @txt    = split /\r?\n/, $txt;
    my $tocnum = 0;
    my $inline = sub { $self->inline(@_) }; # method alias

    my ( @toc, @saved, @result, $verbatim );

    unshift @saved, "</p>";
    push @result, "<p>";

    $self->{saved}  = \@saved;
    $self->{result} = \@result;

    for ( @txt ) {
        chomp;

        # verbatim.
        if ( $verbatim->{func} ) {
            if ( /^\Q$verbatim->{done}\E$/ ) {
                undef $verbatim;
                push @result, splice(@saved);
            }
            else {
                push @result, $verbatim->{func}->($_);
            }
            next;
        }

        # non-verbatim follows.
        if ( @saved and $saved[0] eq '</pre>' and /^[^ \t]/ ) {
            push @result, shift @saved;
        }

        if ( /^(\*{1,3})(.+)/ ) {
            # $hn = 'h2', 'h3' or 'h4'
            my $hn = "h" . (length($1) + 1);
            push(@toc, '-' x length($1) . qq( <a href="#i$tocnum">)
                . &remove_tag($inline->($2)) . qq(</a>\n));
            push(@result, splice(@saved), qq(<$hn><a name="i$tocnum"> </a>)
                . $inline->($2) . qq(</$hn>));
            $tocnum++;
        }
        elsif ( /^(-{2,3})\($/ ) {
            if ( $& eq '--(' ) {
                $verbatim = {
                    func  => $inline,
                    done  => '--)',
                    class => 'verbatim-soft'
                };
            }
            else {
                $verbatim = {
                    func  => \&YukiWiki::Util::escape,
                    done  => '---)',
                    class => 'verbatim-hard'
                };
            }

            $self->back_push( 'pre', 1, " class='$verbatim->{class}'" );
        }
        elsif ( /^----/ ) {
            push @result, splice(@saved), '<hr>';
        }
        elsif ( /^(-{1,3})(.+)/ ) {
            $self->back_push( 'ul', length $1 );
            push @result, '<li>' . $inline->($2) . '</li>';
        }
        elsif ( /^:([^:]+):(.+)/ ) {
            $self->back_push( 'dl', 1 );
            push(@result, '<dt>' . $inline->($1) . '</dt>', '<dd>'
                . $inline->($2) . '</dd>');
        }
        elsif ( /^(>{1,3})(.+)/ ) {
            $self->back_push( 'blockquote', length $1 );
            push @result, $inline->( $2 );
        }
        elsif ( /^$/ ) {
            push @result, splice(@saved);
            unshift @saved, "</p>";
            push @result, "<p>";
        }
        elsif ( /^(\s+.*)$/ ) {
            $self->back_push( 'pre', 1 );
            push @result, YukiWiki::Util::escape($1); # Not &inline, but &escape
        }
        elsif ( /^\,(.*?)[\x0D\x0A]*$/ ) {
            $self->back_push( 'table', 1, ' border="1"' );
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
        }
        elsif ( /^\#(\w+)(\((.*)\))?/ ) {
            # BlockPlugin.
            my $original_line = $_;
            my $plugin_name = $1;
            my $argument = YukiWiki::Util::escape($3);
            my $result = $self->{plugin_manager}->call($plugin_name, 'block', $argument);
            if ( defined $result ) {
                push @result, splice(@saved);
            }
            else {
                $result = $original_line;
            }

            push @result, $result;
        }
        else {
            push @result, $inline->($_);
        }
    }

    push @result, splice(@saved);

    if ( $option{toc} ) {
        # Convert @toc (table of contents) to HTML.
        # This part is taken from Makio Tsukamoto's WalWiki.
        my ( @tocsaved, @tocresult );
        $self->{saved}=\@tocsaved;
        $self->{result}=\@tocresult;
        for ( @toc ) {
            if ( /^(-{1,3})(.*)/ ) {
                $self->back_push( 'ul', length $1 );
                push @tocresult, "<li>$2</li>";
            }
        }

        push @tocresult, splice(@tocsaved);

        # Insert "table of contents".
        if ( @tocresult ) {
            my $resource = $self->{resource};
            unshift @tocresult, qq(<h2>$resource->{table_of_contents}</h2>);
        }

        return join "\n", @tocresult, @result;
    }

    join "\n", @result;
}

sub back_push {
    my $self      = shift;
    my $tag       = shift;
    my $level     = shift;
    my $attr      = shift || q{};
    my $savedref  = $self->{saved};
    my $resultref = $self->{result};

    while ( @$savedref > $level ) {
        push @$resultref, shift @$savedref;
    }

    if ( $savedref->[0] and $savedref->[0] ne "</$tag>" ) {
        push @$resultref, splice(@$savedref);
    }

    while ( @$savedref < $level ) {
        unshift @$savedref, "</$tag>";
        push @$resultref, "<$tag$attr>";
    }

    return;
}

sub remove_tag { # formatter, function
    my $line = shift;
    $line =~ s|\<\/?[A-Za-z][^>]*?\>||g;
    $line;
}

sub inline { # formatter
    my $self = shift;
    my $line = YukiWiki::Util::escape( shift );

    $line =~ s|'''([^']+?)'''|<i>$1</i>|g;  # Italic
    $line =~ s|''([^']+?)''|<b>$1</b>|g;    # Bold
    $line =~ s|(\d\d\d\d-\d\d-\d\d \(\w\w\w\) \d\d:\d\d:\d\d)|<span class="date">$1</span>|g;   # Date

    $line =~ s{
        (
            ((mailto|http|https|ftp):([^\x00-\x20()<>\x7F-\xFF])*)  # Direct http://...
                |
            ($bracket_name)         # [[likethis]], [[#comment]], [[Friend:remotelink]]
                |
            ($interwiki_definition) # [[Friend http://somewhere/?q=sjis($1)]]
                |
            ($wiki_name)            # LocalLinkLikeThis
                |
            ($inline_plugin)        # &user_defined_plugin(123,hello)
        )
    }{ 
        $self->make_link($1)
    }gex;

    $line;
}

sub make_link {
    my ( $self, $chunk ) = @_;

    if ( $chunk =~ /^(http|https|ftp):/ ) {
        if ( $self->{use_autoimg} and $chunk =~ /\.(gif|png|jpeg|jpg)$/ ) {
            return qq(<a href="$chunk"><img src="$chunk"></a>);
        }
        else {
            return qq(<a href="$chunk">$chunk</a>);
        }
    }
    elsif ( $chunk =~ /^(mailto):(.*)/ ) {
        return qq(<a href="$chunk">$2</a>);
    }
    elsif ( $chunk =~ /^$interwiki_definition$/ ) {
        return qq(<span class="InterWiki">$chunk</span>);
    }
    elsif ( $chunk =~ /^$embedded_name$/ ) {
        return $self->context->embedded_to_html( $chunk );
    }
    elsif ( $chunk =~ /^$inline_plugin$/ ) {
        # InlinePlugin.
        my $plugin_name = $1;
        my $argument = $2;
        my $result = $self->{plugin_manager}->call($plugin_name, 'inline', $argument);
        return defined $result ? $result : $chunk;
    }
    else {
        $chunk = YukiWiki::unarmor_name( $chunk );
        $chunk = YukiWiki::Util::unescape( $chunk ); # To treat '&' or '>' or '<' correctly.
        my $cookedchunk  = YukiWiki::Util::encode( $chunk );
        my $escapedchunk = YukiWiki::Util::escape( $chunk );

        if ( $chunk =~ /^$interwiki_name$/ ) {
            my ( $intername, $localname ) = ( $1, $2 );
            #my $remoteurl = $self->interwiki->{$intername};
            my $remoteurl = $self->{interwiki}->{$intername};
            if ($remoteurl =~ /^(http|https|ftp):\/\//) { # Check if scheme if valid.
                $remoteurl =~ s/\b(euc|sjis|ykwk|asis)\(\$1\)/$self->interwiki_convert($1, $localname)/e;
                return qq(<a href="$remoteurl">$escapedchunk</a>);
            }
            else {
                return $escapedchunk;
            }
        }
        elsif ( $self->context->database->{$chunk} ) {
            my $url_cgi = $self->context->cfg('url_cgi');
            my $subject = YukiWiki::Util::escape($self->context->get_subjectline($chunk, delimiter => ''));
            return qq(<a title="$subject" href="$url_cgi/$cookedchunk">$escapedchunk</a>);
        }
        elsif ( $self->context->page_command->{$chunk} ) {
            my $url_cgi = $self->context->cfg('url_cgi');
            return qq(<a title="$escapedchunk" href="$url_cgi/$cookedchunk">$escapedchunk</a>);
        }
        else {
            my $url_cgi = $self->context->cfg('url_cgi');
            #my $editchar = $self->context->cfg('editchar');
            my $editchar = $self->{editchar};
            my $resource = $self->{resource};
            return qq($escapedchunk<a title="$resource->{editthispage}" class="editlink" href="$url_cgi?mycmd=edit&amp;mypage=$cookedchunk">$editchar</a>);
        }
    }
}

sub interwiki_convert {
    my ( $self, $type, $localname ) = @_;

    if ( $type eq 'sjis' or $type eq 'euc' ) {
        YukiWiki::Util::code_convert( \$localname, $type );
        return YukiWiki::Util::encode( $localname );
    }
    elsif ( $type eq 'ykwk' ) {
        # for YukiWiki1
        if ( $localname =~ /^$wiki_name$/ ) {
            return $localname;
        }
        else {
            YukiWiki::Util::code_convert( \$localname, 'sjis' );
            return YukiWiki::Util::encode( "[[" . $localname . "]]" );
        }
    }
    elsif ( $type eq 'asis' ) {
        return $localname;
    }

    $localname;
}

1;
