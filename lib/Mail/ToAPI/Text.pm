package Mail::ToAPI::Text;

use strict;
use 5.010;
our $VERSION = '0.1';
#no warnings 'experimental::smartmatch';

use parent qw/Exporter/;
use HTML::Parser;
use HTML::Entities;
use List::Util qw/reduce first/;
use HTTP::Headers::Util;
use Encode;

our @EXPORT_OK = qw/_parse_for_content/;

sub _parse_header_fields {
    my $fields = { @{(HTTP::Headers::Util::split_header_words($_[0]))[0]} };

    # this is a parser for a subset of RFC2231
    # which is a big brother for RFC2047 MIME words
    # Mozilla Thunderbird uses RFC2231
    if (my $start = first { /\*0\*$/ } keys %$fields) {
        my $value = '';
        $start =~ /^([^*]+)\*0\*$/;
        my $field_name = $1;

        my $counter = 0;
        while (my $next_chunk = delete $fields->{"$field_name*$counter*"}) {
            $value .= $next_chunk;
            ++$counter;
        }
        $value =~ s/^([^']*)'([^']*)'//;
        my ($charset, $lang) = ($1, $2);

        $value =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

        $fields->{$field_name} = $charset
            ? decode($charset, $value)
            : $value;
    }

    return $fields;
}

sub _parse_ct_and_disp {
    my ($ct, $disp) = @_;

    my $ct_parsed = _parse_header_fields("ct=$ct");
    my $ds_parsed = $disp ? _parse_header_fields("d=$disp") : undef;

    return ($ct_parsed, $ds_parsed);
}

sub _conjure_filename {
    my ($ct, $disp) = @_;

    my $res = $disp->{filename} // $ct->{name}
        // do {
            (my $content_type = $ct->{ct}) =~ s{/}{-};
            "$content_type-file";
        };
    if ($res =~ /rfc822-file$/) {
        $res .= ".eml";
    }
    return $res;
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

    my ($ct, $disp) = _parse_ct_and_disp($part->content_type,
        $part->header('Content-Disposition'));

    my $content_type = $ct->{ct} || 'text/plain';

    my $filename = _conjure_filename($ct, $disp);

    if ($disp && $disp->{d} && $disp->{d} eq 'attachment') {
        push @$files, [$filename, $content_type,
            $content_type =~ /^text\// ? $part->body_str : $part->body];
    }
    else {
        given ($content_type) {
            when ('multipart/alternative') {
                # choose the last of all supported, may also be
                # implemented as (grep)[-1]
                # if there's 1 subpart, always return it
                my $best_part = reduce { _may_contain_text($b) ? $b : $a } $part->subparts;
                ($result_str, $files) = _render_recur($best_part);
            }
            when (m{^multipart/}) { # 'mixed', 'related' and all others
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
                push @$files, [$filename, $content_type,
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
    
    $body_str =~ s/ *=\r?\n?\z//s;

    $body_str =~ s/[\r?\n\s]+\z//s;

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
