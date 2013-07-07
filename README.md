# NAME

Mail::ToAPI::Checkvist - Email in tasks for Checkvist.com, see Mail2CV.com

# SYNOPSIS

    use Mail::ToAPI::Checkvist;
or

    % mail2cv.pl < email.eml

# DESCRIPTION

This is the script that powers Mail2CV.com.

It is a service that allows adding tasks to your Checkvist.com list via email.

You will need a fairly modern perl and some modules from CPAN:

uni::perl, WebService::Simple, Email::MIME, Email::Address

You will also need to set up some email forwarding to feed incoming
emails to the script.  I use a catch-all virtual domain in Postfix and
a simple ~/.forward with a pipe.


# AUTHOR

Alex Kapranoff <alex@kapranoff.ru>

# COPYRIGHT

Copyright 2013 Alex Kapranoff

# LICENSE

This library is free software; you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License, Version
3.

# SEE ALSO

http://checkvist.com
