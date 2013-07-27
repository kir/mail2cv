#! /usr/bin/perl
use strict;
use warnings;

use Test::More;

use Test::Script::Run;
use UUID::Tiny;
use File::Temp qw/tempfile/;

use Mail::ToAPI::Checkvist;

my ($test_login, $test_key, $test_list_id) = ('mail2cv@yandex.ru', 'N7DfDkOm0kWf', 203740);
my $test_task = 'test task';
my $test_list_tag = 'inb';
my $test_list_inbox_id = 203772;

my $add_task_job = {
    type        => 'add_task',
    login       => $test_login,
    remotekey   => $test_key,
    list_id     => $test_list_id,

    text        => "$test_task #testtag",

    note        => 'note1',
};

sub ok_task_from_eml {
    my ($eml, $task_text, $task_note) = @_;

    my $uuid = create_UUID_as_string();

    $eml =~ s/^(Subject:.+)$/$1 from email $uuid/m;

    my ($fh, $filename) = tempfile(UNLINK => 1);
    print $fh $eml;
    close $fh;

    close STDIN;
    open STDIN, '<', $filename or die $!;
    run_ok('mail2cv.pl', [], 'mail2cv.pl run');

    my $tasks = Mail::ToAPI::Checkvist::fetch_tasks($test_login, $test_key, $test_list_id);
    my $full_task = (grep { $_->{content} =~ /from email $uuid/ } @$tasks)[0];

    ok($full_task, "task $uuid added");

    if ($task_text) {
        like($full_task->{content}, qr/^$task_text/, 'task text');
    }
    if ($task_note) {
        my $note = $full_task->{notes}->[0]->{note}->{comment};
        $note =~ s/\r//g;
        is($note, $task_note, 'note from email');
    }
}

ok_task_from_eml(<<"EOM", $test_task, 'body');
From: "Mail2CV Tester" <$test_login>
To: <$test_key+$test_list_id\@mail2cv.com>
Subject: $test_task from eml via script

body
EOM

(my $esc_test_login = $test_login) =~ tr/@/$/;
ok_task_from_eml(<<"EOM");
From: "Random Email" <random\@email.com>
To: <$esc_test_login+$test_key+$test_list_id\@mail2cv.com>
Subject: $test_task

body
EOM

ok_task_from_eml(<<"EOM", "$test_task 1", "note!\ntakoe");
MIME-Version: 1.0
From: "Random Email" <random\@email.com>
To: <$esc_test_login+$test_key+$test_list_id\@mail2cv.com>
Subject: $test_task 1
Content-Type: multipart/alternative; boundary=047d7b6dc1a862a67a04e280aa1d

--047d7b6dc1a862a67a04e280aa1d
Content-Type: text/plain; charset=ISO-8859-1

note!
takoe

-- 
Alex Kapranoff.

--047d7b6dc1a862a67a04e280aa1d
Content-Type: text/html; charset=ISO-8859-1

note!<br>takoe<br><br clear="all"><div>-- <br>Alex Kapranoff.</div>

--047d7b6dc1a862a67a04e280aa1d--

EOM

done_testing;
