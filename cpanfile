requires 'perl', '5.008005';

# requires 'Some::Module', 'VERSION';

requires 'WebService::Simple';
requires 'uni::perl';
requires 'Email::MIME';
requires 'Email::Address';
requires 'parent';
requires 'List::Util';
requires 'Config::Tiny';
requires 'HTML::Parser';
requires 'HTML::Entities';

on test => sub {
    requires 'Test::More', '0.88';
    requires 'Test::Deep';
};

on develop => sub {
    requires 'Test::Script::Run';
    requires 'UUID::Tiny';
    requires 'File::Temp';
};
