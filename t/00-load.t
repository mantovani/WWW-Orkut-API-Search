#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'WWW::Orkut::API::Search' ) || print "Bail out!
";
}

diag( "Testing WWW::Orkut::API::Search $WWW::Orkut::API::Search::VERSION, Perl $], $^X" );
