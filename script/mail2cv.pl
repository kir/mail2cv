#!/usr/bin/perl

# Copyright 2013 Alex Kapranoff
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use uni::perl;
use Mail::ToAPI::Checkvist;

$Mail::ToAPI::Checkvist::API_Endpoint = 'https://beta.checkvist.com';

open STDERR, '>>', '/home/kappa/2cv.log';

eval {
    say STDERR scalar localtime;
    my $job = Mail::ToAPI::Checkvist->parse_email(*STDIN);

    say STDERR "for $job->{login}";
    Mail::ToAPI::Checkvist->execute($job);
};

if ($@) {
    say STDERR 'Exception: ', $@;
}

exit 0;
