use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME => 'WWW::Orkut::API::Search',
    AUTHOR =>
      q{Daniel de Oliveira Mantovani <daniel.oliveira.mantovani@gmail.com>},
    VERSION_FROM  => 'lib/WWW/Orkut/API/Search.pm',
    ABSTRACT_FROM => 'lib/WWW/Orkut/API/Search.pm',
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002
        ? ( 'LICENSE' => 'perl' )
        : () ),
    PL_FILES  => {},
    PREREQ_PM => {
        'Test::More'               => 0,
        'Moose'                    => 0,
        'Moose::Role'              => 0,
        'Carp'                     => 0,
        'WWW::Mechanize'           => 0,
        'HTML::TreeBuilder::XPath' => 0,
        'XML::Simple'              => 0,
        'namespace::clean'         => 0,
        'URI::Query'               => 0,
        'URI::Escape'              => 0,
        'aliased'                  => 0
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'WWW-Orkut-API-Search-*' },
);
