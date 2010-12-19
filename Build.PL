use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'WWW::Orkut::API::Search',
    license             => 'perl',
    dist_author         => q{Daniel de Oliveira Mantovani <daniel.oliveira.mantovani@gmail.com>},
    dist_version_from   => 'lib/WWW/Orkut/API/Search.pm',
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'WWW-Orkut-API-Search-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
