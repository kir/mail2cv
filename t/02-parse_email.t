#! /usr/bin/perl
use strict;
use warnings;

use Test::More qw/no_plan/;
use Test::Deep;
use Test::NoWarnings;

use Mail::ToAPI::Checkvist;
use FindBin;

sub is_email_parsed_ok {
    my ($base_eml, $data) = @_;

    open my $fh, '<', "$FindBin::Bin/eml/$base_eml"
        or die "Cannot open $base_eml under $FindBin::Bin: $!";

    my $job = Mail::ToAPI::Checkvist::parse_email($fh);

#    use Data::Dumper;
#    print Dumper($job);

    cmp_deeply($job, superhashof({ %$data, type => 'add_task' }),
        "test in $base_eml");
}

is_email_parsed_ok('01-simple.eml', {
        text        => 'takoe',
        login       => 'vasya@yandex.com',
        remotekey   => 'key1',
    });
