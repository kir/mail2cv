#! /usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Deep;

use Mail::ToAPI::Checkvist;

# attachments are only deployed on beta
$Mail::ToAPI::Checkvist::API_Endpoint = 'https://beta.checkvist.com';

my ($test_login, $test_key, $test_list_id) = ('mail2cv@yandex.ru', 'N7DfDkOm0kWf', 203740);
my $test_task = 'test task';

my $add_task_job = {
    type        => 'add_task',
    login       => $test_login,
    remotekey   => $test_key,
    list_id     => $test_list_id,
    text        => $test_task,

    files       => [
        [ 'example.txt', 'text/plain', 'example text inside' ],
        [ 'example_rus.txt', 'text/plain; charset=utf-8', 'русский' ],
        [ 'blob', 'application/octet-stream', 'example text inside!' ],
    ],
};

my $rv;
ok($rv = Mail::ToAPI::Checkvist->execute($add_task_job), 'task added');

my $tasks = Mail::ToAPI::Checkvist::fetch_tasks($test_login, $test_key, $test_list_id);
my $full_task = (grep { $_->{id} == $rv->{id} } @$tasks)[0];
ok($full_task->{uploads}, "there are files");
is(scalar @{$full_task->{uploads}}, 3, "there are 3 files");

cmp_deeply($full_task->{uploads}, bag(
            superhashof({
                the_file_name => 'example.txt',
                the_content_type => 'text/plain',
                the_file_size => 19
            }),
            superhashof({
                the_file_name => 'example_rus.txt',
                the_content_type => 'text/plain; charset=utf-8',
                the_file_size => 14
            }),
            superhashof({
                the_file_name => 'blob',
                the_content_type => 'application/octet-stream',
                the_file_size => 20
            }),
        ), "all files intact");

done_testing;
