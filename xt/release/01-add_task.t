#! /usr/bin/perl
use strict;
use warnings;

use Test::More;

use Mail::ToAPI::Checkvist;

my ($test_login, $test_key, $test_list) = ('mail2cv@yandex.ru', 'N7DfDkOm0kWf', 203740);
my $test_task = 'test task';

my $rv;
ok($rv = add_task_to_checkvist($test_login, $test_key, $test_list, $test_task), 'task added');
is($rv->{content}, $test_task, 'content matches');
like($rv->{id}, qr/^\d+$/, 'numeric id assigned');

use Test::Script::Run;
use UUID::Tiny;
use File::Temp qw/tempfile/;

my $id = create_UUID_as_string();
my $eml = <<"EOM";
From: "Mail2CV Tester" <$test_login>
To: <$test_key+$test_list\@mail2cv.com>
Subject: $test_task from email $id

body
EOM

my ($fh, $filename) = tempfile(UNLINK => 1);
print $fh $eml;
close $fh;

close STDIN;
open STDIN, '<', $filename or die $!;
run_ok('mail2cv.pl', [], 'mail2cv.pl run');

my $tasks = Mail::ToAPI::Checkvist::fetch_tasks($test_login, $test_key, $test_list);

ok(scalar(grep { $_->{content} =~ /$id/ } @$tasks), 'task from eml added');

done_testing;
