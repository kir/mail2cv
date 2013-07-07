requires 'perl', '5.008005';

# requires 'Some::Module', 'VERSION';

requires 'WebService::Simple';
requires 'uni::perl';
requires 'Email::MIME';
requires 'Email::Address';

on test => sub {
    requires 'Test::More', '0.88';
};
