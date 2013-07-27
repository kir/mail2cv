#! /usr/bin/perl
use strict;
use warnings;

use uni::perl;

use Test::More qw/no_plan/;
use Test::Deep;
use Test::NoWarnings;

use Mail::ToAPI::Checkvist;
use FindBin;

sub job_from_eml {
    my $base_eml = shift;
    open my $fh, '<', "$FindBin::Bin/eml/$base_eml"
        or die "Cannot open $base_eml under $FindBin::Bin: $!";

    return Mail::ToAPI::Checkvist::parse_email($fh);
}

sub is_email_parsed_ok {
    my ($base_eml, $data) = @_;

    my $job = job_from_eml($base_eml);

    cmp_deeply($job, superhashof({ %$data, type => 'add_task' }),
        "test in $base_eml");
}

is_email_parsed_ok('01-simple.eml', {
        text        => 'takoe',
        login       => 'vasya@example.com',
        remotekey   => 'key1',
    });

is_email_parsed_ok('01-simple.eml', {
        note        => 'note1',
    });

is_email_parsed_ok('02-single-html.eml', {
        note        => "note2 in html\nw some Unicode: 🂄 and ♣\nline1\nline2",
    });

cmp_deeply(job_from_eml('021-single-html-only-sig.eml'), {
        type    => 'add_task',
        login   => 'kappa@example.com',
        text    => 'signature only html body',
        list_id => ignore(),
        list_tag=> ignore(),
        remotekey=> ignore(),
    });

is_email_parsed_ok('03-mpalt.eml', {
        note        => "Это первая строка.\nЭто вторая.\n\nЭто третья после пустой.",
    });

is_email_parsed_ok('031-mpalt-ex.eml', {
        note        => "Это первая строка.\nЭто вторая.\n\nЭто третья после пустой.",
    });

is_email_parsed_ok('04-mprel.eml', {
        note        => "Картинка:\n\n После картинки.",
    });

is_email_parsed_ok('05-mpmixed.eml', {
        note        => "A small attachment follows.",
    });
is_email_parsed_ok('051-mpmixed-ex.eml', {
        note        => "A small attachment follows.\n\nSecond text file.",
    });
