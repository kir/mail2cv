#!/usr/bin/perl

use uni::perl;
use WebService::Simple;
use Email::MIME;
use Email::Address;

open STDERR, '>>', '/home/kappa/2cv.log';

sub parse_email_from_stdin {
	my ($from, $to, $subject);

	binmode STDIN, ':bytes';
	my $email = Email::MIME->new(join "", <STDIN>);

	$subject = $email->header('Subject');
	$to   = (Email::Address->parse($email->header_obj->header_raw('To')))[0]->user;
	$from = (Email::Address->parse($email->header_obj->header_raw('From')))[0]->address;

	my ($remotekey, $list_id);
	if	($to =~ /^([^+]+)\+(\d+)$/) {
		($remotekey, $list_id) = ($1, $2);
	}
	elsif	($to =~ /^([^+]+)\+([^+]+)\+(\d+)$/) {
		($from, $remotekey, $list_id) = ($1, $2, $3);
		$from =~ tr/$=/@@/;
	}

	return ($from, $remotekey, $list_id, $subject);
}

sub add_task_to_checkvist {
	my ($login, $remotekey, $list_id, $task_text) = @_;
	my $chv = WebService::Simple->new(
	    base_url    => 'http://checkvist.com/',
	    response_parser => 'JSON',
	);
	$chv->credentials('checkvist.com:80', 'Application', $login, $remotekey);

	$chv->post("checklists/$list_id/tasks.json", {
		'task[content]' => $task_text,
	});
}

eval {
	say STDERR scalar localtime;
	my ($login, $remotekey, $list_id, $task_text)
		= parse_email_from_stdin();
	say STDERR "for $login";
	add_task_to_checkvist($login, $remotekey, $list_id, $task_text);
};

if ($@) {
	say STDERR 'Exception: ', $@;
}

exit 0;
