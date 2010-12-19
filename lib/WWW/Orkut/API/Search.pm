package WWW::Orkut::API::Search;

use Moose;
use Carp;
use WWW::Mechanize;
use aliased 'HTML::TreeBuilder::XPath';
use XML::Simple;
use namespace::clean;
use URI::Query;
use URI::Escape;
use utf8;

our $VERSION = '0.1';

use constant url_cmd       => '/CommTopics?cmm=';
use constant busca_tpc_url => '/UniversalSearch?pno=1&searchFor=F&q=';
use constant busca_brasil  => '&loc=C';

binmode STDOUT, ':utf8';

with 'WWW::Orkut::API::Search::Role';

has 'url_login' => (
    is  => 'ro',
    isa => 'Str',
    default =>
'https://www.google.com/accounts/ServiceLogin?service=orkut&hl=en-US&rm=false&continue=http://www.orkut.com/RedirLogin?msg%3D0%26page%3Dhttp://www.orkut.com.br/Home&cd=BR&passive=true&skipvpage=true&sendvemail=false'
);
has 'email'    => ( is => 'rw', isa => 'Str', required => 1 );
has 'password' => ( is => 'rw', isa => 'Str', required => 1 );
has 'mechanize' => (
    is      => 'ro',
    isa     => 'WWW::Mechanize',
    default => sub {
        WWW::Mechanize->new(
            timeout     => 10,
            agent_alias => 'Linux Mozilla',
            stack_depth => 10
        );
    },
);

=head2 logar

Se loga no Orkut, retornando a página inicial.

=cut

sub logar {
    my $self = shift;
    $self->mechanize->get( $self->url_login );
    $self->mechanize->submit_form(
        form_number => 1,
        fields      => {
            'Email'             => $self->email,
            'Passwd'            => $self->password,
            'PersistentCookie=' => 'Yes',
        }
    );
    $self->mechanize->follow_link( n => 1 );

    # Se tu passar a url completa nao funciona, tem que passar o PATH

    $self->mechanize->get('/Home.aspx');

    confess "usuario/senha invalidos" if $self->mechanize->title !~ /orkut/;

    return $self->mechanize;
}

=head2 BUILD

Método do Moose que é executado logo após o new,
estou me logando logo após o new.

=cut

sub BUILD {
    shift->logar;
}

=head2 get_tpc

Começa a fazer o parser do orkut, você precisa passar o id
da cmd.

    my $comunidade_id = '4684637';
    my $element       = $spider->get_tpc($comunidade_id);


=cut

sub get_tpc {
    my ( $self, $cmd_id ) = @_;
    confess 'Precisa passar o id' unless $cmd_id;

    my $mech = $self->mechanize->clone;
    $mech->get( url_cmd . $cmd_id );
    my $element = XPath->new_from_content( $mech->content );
    return $element;
}

=head2 ir_next_pagina_tpc

Vai para a próxima página do tópico, retornando
o element da próxima página.

    my $comunidade_id = '4684637';
    my $element       = $spider->get_tpc($comunidade_id);
    my $infs          = $spider->tpc_parser($element);

    foreach my $tpc_id ( keys %{$infs} ) {

        # - Primeira página do fórum da comunidade que
        # tem os tópicos, imprime todos.
        print Dumper $infs->{$tpc_id};
    }
    while ( $element = $spider->ir_next_pagina_tpc($element) ) {
        my $infs = $spider->tpc_parser($element);

        foreach my $tpc_id ( keys %{$infs} ) {

            # - Segunda em diante  página do fórum da comunidade que
            #tem os tópicos, imprime todos.
            print Dumper $infs->{$tpc_id};
        }
    }


=cut

sub ir_next_pagina_tpc {
    my ( $self, $element ) = @_;
    my $url_next = $self->_tpc_proxima_pagina_url($element);
    return $element->delete unless $url_next;

    my $mech = $self->mechanize->clone;
    $mech->get($url_next);
    $element = $element->delete;
    return $element = XPath->new_from_content( $mech->content );
}

=head2 tpc_parser

Faz o parser das informações do tópico,
tpc_id;
tpc_titulo;
tpc_autor;
tpc_autor_id;
tpc_numero_posts;


    my $comunidade_id = '52903';
    my $element       = $spider->get_tpc($comunidade_id);
    my $infs          = $spider->tpc_parser($element);

    foreach my $tpc_id ( keys %{$infs} ) {
        print Dumper $infs->{$tpc_id};
    }



=cut

sub tpc_parser {
    my ( $self, $element ) = @_;
    my $infos = {};
    my $topicos =
      $element->findnodes('//table[@class="displaytable"]//tr[@class=~/list/]');
    foreach my $tpc ( @{$topicos} ) {
        my $tpc_id = $self->_tpc_id($tpc);
        $infos->{$tpc_id} = {
            tpc_titulo       => $self->_tpc_titulo($tpc),
            tpc_autor        => $self->_tpc_autor($tpc),
            tpc_autor_id     => $self->_tpc_autor_id($tpc),
            tpc_numero_posts => $self->_tpc_numero_posts($tpc),
        };
    }
    return $infos;
}

=head2 get_tpc_thread

Se passa como argumento o ID da cmd e o 
ID do tópico, e retorna um elemento.

	my $thread_element = $spider->get_tpc_thread( $comunidade_id, $tpc_id );

=cut

sub get_tpc_thread {
    my ( $self, $cmd_id, $tpc_id ) = @_;

    confess 'Precisa passar o id' unless $tpc_id || $cmd_id;

    my $mech = $self->mechanize->clone;
    $mech->get( $self->_uri_thread( $cmd_id, $tpc_id ) );
    my $thread_element = XPath->new_from_content( $mech->content );
    return $thread_element

}

=head2 _uri_thread

Retorna a URI da thread

=cut

sub _uri_thread {
    my $self = shift;
    my $u    = URI->new('/CommMsgs');
    $u->query_form( { cmm => shift, tid => shift } );
    return $u->as_string;
}

=head2 tpc_thread_parser

Responsável por fazer o parser da thread,
[usuario_nome, usuario_id , msg_texto]
Ele busca nas mensagens(msg) as informações.

	my $thread_element = $spider->get_tpc_thread( $comunidade_id, $tpc_id );
	my $thread_infs = $spider->tpc_thread_parser($thread_element);
	
	# - Imprime o conteúdo dentro do tópico a thread,
	#aqui imprime a primeira página.
	print Dumper $thread_infs;

=cut

sub tpc_thread_parser {
    my ( $self, $thread_element ) = @_;

    my $msgs        = $self->_tpc_thread_all_itens($thread_element);
    my $thread_infs = [];
    for ( my $i = 0 ; $i <= ( @{$msgs} - 1 ) ; $i++ ) {
        $thread_infs->[$i] = {
            usuario_nome => $self->_tpc_thread_msg_nome( $msgs->[$i] ),
            usuario_id   => $self->_tpc_thread_msg_nome_id( $msgs->[$i] ),
            msg_texto    => $self->_tpc_thread_msg_texto( $msgs->[$i] ),
        };
    }
    return $thread_infs;
}

=head2 ir_next_pagina_tpc_thread

Responsável por ir até a próxima página da thread.

    # - Começa a fazer o parser da thread do tópico.
    my $thread_element = $spider->get_tpc_thread( $comunidade_id, $tpc_id );
    my $thread_infs = $spider->tpc_thread_parser($thread_element);

    # - Imprime o conteúdo dentro do tópico a thread,
    #aqui imprime a primeira página.
    print Dumper $thread_infs;

    foreach my $thread_inf ( @{$thread_infs} ) { 
        while ( my $thread_element =
            $spider->ir_next_pagina_tpc_thread($thread_element) )
        {   
            my $thread_infs = $spider->tpc_thread_parser($thread_element);

            # - Imprime o conteúdo dentro do tópico a thread
            #aqui imprime a segunda página em diante.
            print Dumper $thread_infs;
        }   
    }   

=cut

sub ir_next_pagina_tpc_thread {
    my ( $self, $thread_element ) = @_;
    my $url_next = $self->_tpc_thread_proxima_pagina_url($thread_element);
    return $thread_element->delete unless $url_next;

    my $mech = $self->mechanize->clone;
    $mech->get($url_next);
    $thread_element = $thread_element->delete;
    return $thread_element = XPath->new_from_content( $mech->content );
}

=head2 busca_tpc

Faz a busca no Orkut nos tópicos com as palavras chaves que você digitar,
retornando o elemento com os resultados.

    my $busca       = 'jacotei zuera';
    my $tpc_element = $spider->busca_tpc($busca);
    my $infs_busca  = $spider->busca_tpc_parser($tpc_element);
    
	# - comunidade_id, tpc_id    
    say $_->[0], "\t", $_->[1] for @{$infs_busca};

=cut

sub busca_tpc {
    my ( $self, $busca ) = @_;

    confess "Precisa passar a busca" unless $busca;
    $busca =~ s/\s/\+/g;

    my $mech = $self->mechanize->clone;
    $mech->get( busca_tpc_url . $busca . busca_brasil );

    my $tpc_busca_element = XPath->new_from_content( $mech->content );
    return $tpc_busca_element;
}

=head2 busca_tpc_parser

Faz o parser dos resultados encontrados, recebe como argumento
o elemento que contem o resultado das buscas.
Essa função retorna:
id do tópico, id da comunidade,titulo do tópico, e um array com as
mensagens envolvendo aquele tópico que contenha as palavras da busca.

    use Data::Dumper;

    use aliased 'WWW::Orkut::API::Search';

    my $spider = Interface->new(
        email    => 'user',
        password => 'pass'
    );

    my $busca       = 'jacotei zura';
    my $tpc_element = $spider->busca_tpc($busca);
    my $infs_busca  = $spider->busca_tpc_parser($tpc_element);

    foreach my $a ( @{$infs_busca} ) {
      
        print $a->{'titulo_tpc'}, "\t", $a->{'id_comunidade'}, "\t",
          $a->{'id_topico'}, "\n";
        
        foreach my $c ( @{ $a->{'mensagens'} } ) {
    
            print Dumper $c;

        }

    }



=cut

sub busca_tpc_parser {
    my ( $self, $tpc_busca_element ) = @_;
    my $busca_items = $self->_busca_tpc_parser_itens($tpc_busca_element);
    return $tpc_busca_element->delete unless $busca_items;

    my $busca_infs = [];

    foreach my $item ( @{$busca_items} ) {
        push( @{$busca_infs}, $self->_busca_tpc_parser_tpc_id($item) );
    }
    return $busca_infs;
}

__PACKAGE__->meta->make_immutable;
1;
__END__

=head1 NAME

WWW::Orkut::API::Search - API for Orkut

=head1 SYNOPSIS

    use WWW::Orkut::API::Search;
    use Data::Dumper;
    my $spider = WWW::Orkut::API::Search->new(
        email    => "...",
        password => "..."
    );
    my $comunidade_id = '117916';
    my $element = $spider->get_tpc($comunidade_id);
    my $infs    = $spider->tpc_parser($element);

    # - Primeira página do fórum da comunidade que tem os tópicos,
    #imprime todos.
    print_stuffs($infs);
    while ( $element = $spider->ir_next_pagina_tpc($element) ) {
        my $infs = $spider->tpc_parser($element);

        # - Segunda em diante  página do fórum da comunidade que tem
        #os tópicos, imprime todos.
        print_stuffs($infs);
    }
    sub print_stuffs {
        foreach my $tpc_id ( keys %{$infs} ) {
            print "Topico_ID => $tpc_id\t", $infs->{$tpc_id}{'tpc_autor'}, "\n";

            # - Começa a fazer o parser da thread do tópico.
            my $thread_element =
              $spider->get_tpc_thread( $comunidade_id, $tpc_id );
            my $thread_infs = $spider->tpc_thread_parser($thread_element);
        
            # - Imprime o conteúdo dentro do tópico a thread,
            #aqui imprime a primeira página.
            print Dumper $thread_infs;
        
            foreach my $thread_inf ( @{$thread_infs} ) {
                while ( my $thread_element =
                    $spider->ir_next_pagina_tpc_thread($thread_element) )
                {
                    my $thread_infs =
                      $spider->tpc_thread_parser($thread_element);
                
                    # - Imprime o conteúdo dentro do tópico a thread
                    #aqui imprime a segunda página em diante.
                    print Dumper $thread_infs;
                }
            }
        }
    }


=head1 VERSION

Version 0.01


=head1 AUTHOR

Daniel de Oliveira Mantovani, C<< <daniel.oliveira.mantovani at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-www-orkut-api-search at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=WWW-Orkut-API-Search>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc WWW::Orkut::API::Search


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=WWW-Orkut-API-Search>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/WWW-Orkut-API-Search>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/WWW-Orkut-API-Search>

=item * Search CPAN

L<http://search.cpan.org/dist/WWW-Orkut-API-Search/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Daniel de Oliveira Mantovani.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of WWW::Orkut::API::Search
