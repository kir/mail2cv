package Mail::ToAPI::Text;

use strict;
use 5.010;
our $VERSION = '0.1';

use parent qw/Exporter/;
use HTML::Parser;
use HTML::Entities;
use List::Util qw/reduce/;
use HTTP::Headers::Util;

our @EXPORT_OK = qw/_parse_for_content/;

sub _parse_header_fields {
    return { @{(HTTP::Headers::Util::split_header_words($_[0]))[0]} }
}

sub _ct {
    my $data = _parse_header_fields("ct=$_[0]");

    return $data->{ct};
}

sub _may_contain_text {
    my $part = shift;

    my $ct = _parse_header_fields("ct=" . $part->content_type);

    return  $ct->{ct} =~ m{^multipart/}i
        || ($ct->{ct} =~ m{^text/(?:plain|html)$}i
            && ($part->header('Content-Disposition') || '') !~ /^attachment\b/i);
}

sub _render_recur {
    my $part = shift;
    my ($result_str, $files) = ('', undef);

    my $content_type = _ct($part->content_type) || 'text/plain';

    my $disp;
    if (my $cd = $part->header('Content-Disposition')) {
        $disp = _parse_header_fields("d=$cd");
    }

    if ($disp->{d} && $disp->{d} eq 'attachment') {
        push @$files, [$disp->{filename}, $content_type,
            $content_type =~ /^text\// ? $part->body_str : $part->body];
    }
    else {
        given ($content_type) {
            when ('multipart/related') {
                ($result_str, $files) = _render_recur(($part->subparts)[0]);
            }
            when ('multipart/alternative') {
                # choose the last of all supported, may also be
                # implemented as (grep)[-1]
                # if there's 1 subpart, always return it
                my $best_part = reduce { _may_contain_text($b) ? $b : $a } $part->subparts;
                ($result_str, $files) = _render_recur($best_part);
            }
            when (m{^multipart/}) { # 'mixed' and all others
                for my $subpart ($part->subparts) {
                    my ($part_str, $part_files) = _render_recur($subpart);
                    if (_may_contain_text($subpart)) {
                        $result_str .= $part_str . "\n";
                    }
                    push @$files, @$part_files if $part_files;
                }
                $result_str =~ s/\n\z//; # emulate join
            }
            when ('text/html') {
                $result_str = textify_html($part->body_str);
            }
            when (m{^text/}) {
                $result_str = $part->body_str;
            }
            default {
                # cannot render this part inline, so emulate attachment
                # should not happen very often
                push @$files, [$disp->{filename}, $content_type,
                    $content_type =~ /^text\// ? $part->body_str : $part->body];
            }
        }
    }

    return ($result_str, $files);
}

sub _parse_for_content {
    my $email = shift;

    my ($body_str, $files) = _render_recur($email);

    $body_str =~ s/^\s+//s;

    $body_str =~ s/(?:\r?\n|^)--[ ]?\r?\n.*\z//s;

    $body_str =~ s/\s+\z//s;

    return ($body_str, $files);
}

*unescapeHTMLFull = \&HTML::Entities::decode_entities;

sub textify_html($) {
    my $p = new HTML::Parser
        api_version => 3,
        start_h     => [\&_textify_tag, 'self, tagname, skipped_text, attr'],
        end_h       => [\&_textify_end_tag, 'self, tagname, skipped_text'],
        end_document_h=> [ sub { $_[0]->{result} .= _textify_decode($_[1]) }, 'self, skipped_text'],
        process_h   => [""],
        declaration_h=> [""],
        comment_h   => [""];

    $p->{result} = '';
    $p->{inside_bad_element} = undef;

    $p->parse($_[0]); # html (first arg)
    $p->eof;

    $p->{result} =~ s/[ \n\r\t]*\n[ \n\r\t]*\n/\n\n/gs;

    $p->{result} =~ s/\s+\z/\n/s;

    return $p->{result};
}

sub _textify_tag {
    my ($p, $tag, $skipped, $attrs) = @_;

    return if $p->{inside_bad_element};

    $skipped =~ s/\s+/ /sg; # Multiple spaces,newlines in html is simple space
    $p->{result} .= _textify_decode($skipped);

    if ($tag eq 'script' || $tag eq 'style') {
        $p->{inside_bad_element} = $tag;
        return;
    }

    if ($tag eq 'br' || $tag eq 'p' || $tag eq 'div') {
        $p->{result} .= "\n" if $p->{result} ne q{};

    } elsif ($tag eq 'hr') {
        $p->{result} .= "\n" . '-' x 50 . "\n";

    } elsif ($tag eq 'a') {
        $p->{a_href} = $attrs->{href}; # Save href for comparison with text content
        $p->{a_href_start} = length($p->{result});
    }
}

sub _textify_end_tag {
    my ($p, $tag, $skipped) = @_;

    unless ($p->{inside_bad_element}) {
        $skipped =~ s/\s+/ /sg; # Multiple spaces,newlines in html is simple space
        $p->{result} .= _textify_decode($skipped);
    } elsif ($p->{inside_bad_element} eq $tag) {
        $p->{inside_bad_element} = undef
    }

    # '<a href="URL">here</a>' => 'here [URL]'
    if ($tag eq 'a' && $p->{a_href}) {
        my $href    = $p->{a_href};
        $href =~ s{^(?:
                http:// (?=www\.) |
                ftp://  (?=ftp\.) |
                mailto:
            ) }{}xi;
        $href =~ s{/$}{};

        if (substr($p->{result}, $p->{a_href_start}) !~ /\Q$href\E/i) { # Content not contail URL?
            $p->{result} .= (substr($p->{result}, -1) eq ' ' ? '' : ' ') .
                '[' . $p->{a_href} . ']';
        }
        undef $p->{a_href}, $p->{a_href_start};
    }
}

sub _textify_decode {
    my $t = unescapeHTMLFull($_[0]);
    $t =~ tr/\xA0/ /; # nbsp => space
    return $t;
}

1;
