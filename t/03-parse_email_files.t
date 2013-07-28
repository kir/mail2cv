#! /usr/bin/perl
use strict;
use warnings;

use uni::perl;

use Test::More;
use Test::Deep;
#use Test::NoWarnings;

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

is_email_parsed_ok('05-mpmixed.eml', {
        note        => "A small attachment follows.",
    });
is_email_parsed_ok('051-mpmixed-ex.eml', {
        note        => "A small attachment follows.\n\nSecond text file.",
    });

is_email_parsed_ok('06-one-file.eml', {
        text        => 'simple attach',
        note        => 'Привет! Вот файл.',
        files       => [
            [ 'example.txt', 'text/plain', "1\n" ],
        ],
    });

my $two_files = job_from_eml('07-two-files.eml');
cmp_deeply($two_files, superhashof({
        text        => '2 attachments',
        note        => "See attached.\n\nAlex Kapranoff.",
        files       => [
            [ 'dist.ini', 'application/octet-stream', "[\@Milla]\n[RunExtraTests]\n" ],
            [ 'indicator3.gif', 'image/gif', ignore() ],
        ],
    }), '07-two-files');
is(length($two_files->{files}->[1]->[2]), 1235, 'base64 image/gif size');

is_email_parsed_ok('08-two-files-rusnames.eml', {
        text        => '2 attachments from аутлук.ком',
        note        => 'см. файлы с русскими именами',
        files       => [
            [ 'пример.txt', 'text/plain', "1\n" ],
            [ 'очень-длинное-имя-файла-на-русском-йййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййй.bin', 'application/octet-stream', "1\n" ],
        ],
    });

done_testing;
