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
        files       => [
            ['1.txt', 'text/plain', "1\n"],
        ],
    });
is_email_parsed_ok('051-mpmixed-ex.eml', {
        note        => "A small attachment follows.\nSecond text file.",
        files       => [
            ['x-something-something-file', 'x-something/something', "Third text file.\n"],
        ],
    });
is_email_parsed_ok('052-mpmixed-noname.eml', {
        note        => "A small attachment follows.",
        files       => [ 
			[ 'text-plain-file', 'text/plain', "1\n"]
        ],
    });

is_email_parsed_ok('053-noname-rfc822-message.eml', {
        note        => "A small attachment follows.",
        files       => [ 
			[ 'message-rfc822-file.eml', 'message/rfc822', "1\n"]
        ],
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

is_email_parsed_ok('09-rel-files-thund.eml', {
        text        => 'из thunderbird',
        note        => "текст\n\n ещё текст\n\n ещё текст 2",
        files       => [
            [ 'gfhgfagf.gif', 'image/gif', ignore() ],
            [ 'очень-длинное-имя-файла-на-русском-йййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййййй.bin', 'application/octet-stream', "1\n" ],
        ],
    });

is_email_parsed_ok('10-rel-img-gmail.eml', {
        text        => 'task task task!',
        note        => '111',
        files       => [
            [ 'CAM00021.jpg', 'image/jpeg', ignore() ],
        ],
    });

done_testing;
