package Mail::ToAPI::Checkvist;

use strict;
use 5.010;
our $VERSION = '0.1';

use WebService::Simple;
use Email::MIME;
use Email::Address;
use List::Util qw/first/;

our $Chv;
our $Last_Error;

sub _init_api {
    my ($login, $remotekey) = @_;

    unless ($Chv) {
        $Chv = WebService::Simple->new(
            base_url    => 'http://checkvist.com/',
            response_parser => 'JSON',
        );

        $Chv->credentials('checkvist.com:80', 'Application', $login, $remotekey);
    }

    return $Chv;
}

sub _parse_to {
    my $to = shift;
    my ($login, $remotekey, $list_id, $list_tag);

    $to   = (Email::Address->parse($to))[0]->user;

    # = given, but I need "redo"
    for ($to) {
        s/^ post \+//xms;

        # we do not allow "." in remotekey to distinguish between
        # user$domain.com+remotekey@ and
        # remotekey+list_tag
        # fortunately, Checkvist remotekeys do not contain "."
        when (/^ ([^+.]+) \+ (\d+) $/xms) {
            ($remotekey, $list_id) = ($1, $2);
        }
        when (/^ ([^+.]+) \+ ([^+]+) $/xms) {
            ($remotekey, $list_tag) = ($1, $2);
        }
        when (/^ ([^+.]+) $/xms) {
            $remotekey = $1;
        }

        if (s/^ ([^+]+) \+ //xms) {
            $login = $1;
            $login =~ tr/$=/@@/;

            redo;
        }
    }

    return ($login, $remotekey, $list_id, $list_tag);
}

sub parse_email {
    my $fh = pop;

    my ($from, $to, $subject);

    binmode $fh, ':bytes';
    my $email = Email::MIME->new(join "", <$fh>);

    $subject = $email->header('Subject');
    $from = (Email::Address->parse($email->header_obj->header_raw('From')))[0]->address;

    my ($login, $remotekey, $list_id, $list_tag) = _parse_to($email->header_obj->header_raw('To'));

    $Last_Error = '';
    return {
        type        => 'add_task',

        login       => $login // $from,
        remotekey   => $remotekey,

        list_id     => $list_id,
        list_tag    => $list_tag,
        text        => $subject
    };
}

sub execute {
    my $job = pop;

    my $rv;

    eval {
        given ($job->{type}) {
            when ('add_task') {
                $rv = _add_task($job);
            }
        }
    };

    if ($@) {
        $Last_Error = $@;
        undef $rv;
    }
    else {
        $Last_Error = '';
    }

    return $rv;
}

sub _add_task {
    my $job = shift;

    my $chv = _init_api($job->{login}, $job->{remotekey});

    unless ($job->{list_id}) {
        my $list_tag = $job->{list_tag} // 'inbox';   # default
        my $lists = $chv->get("checklists.json")->parse_response;

        if (my $list = first { $_->{tags}->{$list_tag} eq 'false' } @$lists) {
            $job->{list_id} = $list->{id};
        }
        else {
            die "list tag not found\n";
        }
    }

    my $rv =
        $chv->post("checklists/$job->{list_id}/import.json", {
            import_content  => $job->{text},
            parse_tasks     => 1,
        });

    return $rv && $rv->parse_response->[0];
}

sub fetch_tasks {
    my ($login, $remotekey, $list_id) = @_;
    my $chv = _init_api($login, $remotekey);

    my $rv = $chv->get("checklists/$list_id/tasks.json");

    return $rv && $rv->parse_response;
}

sub last_error {
    return $Last_Error;
}

1;
__END__

=encoding utf-8

=head1 NAME

Mail::ToAPI::Checkvist - Email in tasks for Checkvist.com, see Mail2CV.com

=head1 SYNOPSIS

  use Mail::ToAPI::Checkvist;

or

  % mail2cv.pl < email.eml

=head1 DESCRIPTION

This is the script that powers Mail2CV.com.

It is a service that allows adding tasks to your Checkvist.com list via email.

You will need a fairly modern perl and some modules from CPAN:

uni::perl, WebService::Simple, Email::MIME, Email::Address

You will also need to set up some email forwarding to feed incoming
emails to the script.  I use a catch-all virtual domain in Postfix and
a simple ~/.forward with a pipe.

=head1 AUTHOR

Alex Kapranoff E<lt>alex@kapranoff.ruE<gt>

=head1 COPYRIGHT

Copyright 2013 Alex Kapranoff

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License, Version
3.

=head1 SEE ALSO

L<http://checkvist.com>

=cut
