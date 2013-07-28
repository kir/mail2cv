#! /usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::NoWarnings;

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
my $rv;
ok($rv = Mail::ToAPI::Checkvist->execute($add_task_job), 'task added');

is($rv->{content}, $test_task, 'content matches');
like($rv->{id}, qr/^\d+$/, 'numeric id assigned');

is($rv->{checklist_id}, $test_list_id, 'correct list chosen');

my $tasks = Mail::ToAPI::Checkvist::fetch_tasks($test_login, $test_key, $test_list_id);
my $full_task = (grep { $_->{id} == $rv->{id} } @$tasks)[0];
ok($full_task->{notes}, "there are notes");
is($full_task->{notes}->[0]->{note}->{comment}, 'note1', "correct note was added");

delete $add_task_job->{note};

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

done_testing;
