#! /usr/bin/perl
use strict;
use warnings;

use uni::perl;

use Test::More;
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
    my ($base_eml, $data, $files_present) = @_;

    my $job = job_from_eml($base_eml);

    cmp_deeply($job, superhashof({ %$data, type => 'add_task' }),
        "test in $base_eml");
    $files_present or ok(!$job->{files}, "no files in $base_eml");
}

is_email_parsed_ok('01-simple.eml', {
        text        => 'takoe',
        login       => 'vasya@example.com',
        remotekey   => 'key1',
    });

is_email_parsed_ok('01-simple.eml', {
        note        => 'note1',
    });

is_email_parsed_ok('011-simple-no-subject.eml', {
    	text        => 'note133',
    });

is_email_parsed_ok('012-simple-no-subject-multiline.eml', {
    	text        => 'note1',
        note        => "note1\nnote1",
    });
is_email_parsed_ok('013-simple-blank-subject.eml', {
    	text        => 'note1',
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
    }, '021-single-html-only-sig');

is_email_parsed_ok('03-mpalt.eml', {
        note        => "Это первая строка.\nЭто вторая.\n\nЭто третья после пустой.",
    });

is_email_parsed_ok('031-mpalt-ex.eml', {
        note        => "Это первая строка.\nЭто вторая.\n\nЭто третья после пустой.",
    });

is_email_parsed_ok('04-mprel.eml', {
        note        => "Картинка:\n\n После картинки.",
    }, 'увы');

done_testing;
