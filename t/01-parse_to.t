#! /usr/bin/perl
use strict;
use warnings;

use Test::More;
use Test::Deep;

use Mail::ToAPI::Checkvist;
*parse_to = \&Mail::ToAPI::Checkvist::_parse_to;

# ($login, $remoteley, $list_id, $list_tag);
my @rv;

cmp_deeply([parse_to('key1+123@mail2cv.com')], [undef, 'key1', 123, undef], 'basic key');
cmp_deeply([parse_to('from$gmail.com+key1+123@mail2cv.com')], ['from@gmail.com', 'key1', 123, undef], 'w/ from');
cmp_deeply([parse_to('from=gmail.com+key1+123@mail2cv.com')], ['from@gmail.com', 'key1', 123, undef], 'w/ from');
cmp_deeply([parse_to('key1+inb@mail2cv.com')], [undef, 'key1', undef, 'inb'], 'list tag');
cmp_deeply([parse_to('key1@mail2cv.com')], [undef, 'key1', undef, undef], 'lonely key');
cmp_deeply([parse_to('from=gmail.com+key1@mail2cv.com')], ['from@gmail.com', 'key1', undef, undef], 'key w/ from');
cmp_deeply([parse_to('post+key1@mail2cv.com')], [undef, 'key1', undef, undef], 'post+key');
cmp_deeply([parse_to('post+key7+3332@mail2cv.com')], [undef, 'key7', 3332, undef], 'post+key+list_id');
cmp_deeply([parse_to('post+key7+work@mail2cv.com')], [undef, 'key7', undef, 'work'], 'post+key+tag');
cmp_deeply([parse_to('post+takoe$yandex.com+key42@mail2cv.com')], ['takoe@yandex.com', 'key42', undef, undef], 'post+from+key');
cmp_deeply([parse_to('me=gmail.com+key3+inbox@mail2cv.com')], ['me@gmail.com', 'key3', undef, 'inbox'], 'w/ from and list_tag');

cmp_deeply([parse_to('kappa@mail2cv.com')], [undef, 'kappa', undef, undef], 'degenerate case of simple email address');
cmp_deeply([parse_to('post+key2@checkvist.com')], [undef, 'key2', undef, undef], 'what Kirill wants');

done_testing;
