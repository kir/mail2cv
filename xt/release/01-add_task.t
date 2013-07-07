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
};
my $rv;
ok($rv = Mail::ToAPI::Checkvist->execute($add_task_job), 'task added');

is($rv->{content}, $test_task, 'content matches');
like($rv->{id}, qr/^\d+$/, 'numeric id assigned');

is($rv->{tags}->{testtag}, 'false', 'tag parsing works');

delete $add_task_job->{list_id};
$add_task_job->{list_tag} = $test_list_tag;

ok($rv = Mail::ToAPI::Checkvist->execute($add_task_job), 'task added by existing tag');
is($rv->{checklist_id}, $test_list_id, 'found the correct list');

delete $add_task_job->{list_id};
$add_task_job->{list_tag} = $test_list_tag . 'xxx';
ok(!Mail::ToAPI::Checkvist->execute($add_task_job), 'tag does not exist');
like(Mail::ToAPI::Checkvist->last_error, qr/list tag not found/, 'correct last error');

delete $add_task_job->{list_id};
delete $add_task_job->{list_tag};
ok($rv = Mail::ToAPI::Checkvist->execute($add_task_job), 'task added by default tag');
is($rv->{checklist_id}, $test_list_inbox_id, 'found the correct list');

sub ok_task_from_eml {
    my $eml = shift;

    my $uuid = create_UUID_as_string();

    $eml =~ s/^(Subject:.+)$/$1 from email $uuid/m;

    my ($fh, $filename) = tempfile(UNLINK => 1);
    print $fh $eml;
    close $fh;

    close STDIN;
    open STDIN, '<', $filename or die $!;
    run_ok('mail2cv.pl', [], 'mail2cv.pl run');

    my $tasks = Mail::ToAPI::Checkvist::fetch_tasks($test_login, $test_key, $test_list_id);

    ok(scalar(grep { $_->{content} =~ /from email $uuid/ } @$tasks), "task $uuid added");
}

ok_task_from_eml(<<"EOM");
From: "Mail2CV Tester" <$test_login>
To: <$test_key+$test_list_id\@mail2cv.com>
Subject: $test_task

body
EOM

(my $esc_test_login = $test_login) =~ tr/@/$/;
ok_task_from_eml(<<"EOM");
From: "Random Email" <random\@email.com>
To: <$esc_test_login+$test_key+$test_list_id\@mail2cv.com>
Subject: $test_task

body
EOM

done_testing;
