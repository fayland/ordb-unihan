#!perl

use Test::More tests => 1;

BEGIN {
    use_ok('ORDB::Unihan');
}

diag(
"Testing ORDB::Unihan $ORDB::Unihan::VERSION, Perl $], $^X"
);
