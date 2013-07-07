package Mail::ToAPI::Checkvist;

use strict;
use 5.008_005;
our $VERSION = '0.01';

use WebService::Simple;
use Email::MIME;
use Email::Address;

use Exporter;

our @EXPORT = qw/parse_email_from_stdin add_task_to_checkvist/;

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

1;
__END__

=encoding utf-8

=head1 NAME

Mail::ToAPI::Checkvist - Email in tasks for Checkvist.com, see Mail2CV.com

=head1 SYNOPSIS

  use Mail::ToAPI::Checkvist;

=head1 DESCRIPTION

Mail::ToAPI::Checkvist is

=head1 AUTHOR

Alex Kapranoff E<lt>alex@kapranoff.ruE<gt>

=head1 COPYRIGHT

Copyright 2013 Alex Kapranoff

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License, Version
3.

=head1 SEE ALSO

http://checkvist.com

=cut
