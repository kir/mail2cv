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

done_testing;
