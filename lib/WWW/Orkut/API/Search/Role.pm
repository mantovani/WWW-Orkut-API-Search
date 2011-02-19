package WWW::Orkut::API::Search::Role;

use Moose::Role;
use URI::Escape;

our $VERSION = '0.2';

=head2 _tpc_id

Retorna o ID do tópico

=cut

sub _tpc_id {
    my ( $self, $element ) = @_;
    my $uri = URI::Query->new( $element->findnodes('.//a')->[0]->attr('href') );
    return $uri->hash->{'tid'};
}

=head2 _tpc_titulo 

Retorna o titulo do tópico

=cut

sub _tpc_titulo {
    my ( $self, $element ) = @_;
    return $element->findnodes('.//a')->[0]->as_text;
}

=head2 _tpc_autor

Retorna o nome do autor que criou o tópico

=cut

sub _tpc_autor {
    my ( $self, $element ) = @_;
    return $element->findvalue('.//td[3]/a');
}

=head2 _tpc_autor_id

Retorna o ID do nome do autor que criou o tópico

=cut

sub _tpc_autor_id {
    my ( $self, $element ) = @_;
    if ( my $link_autor = $element->findnodes('.//td[3]/a')->[0] ) {
        my $uri = URI::Query->new( $link_autor->attr('href') );
        return $uri->hash->{'/Main#Profile?uid'};
    }
    return 'null';
}

=head2 _tpc_numero_posts

Retorna o numero de posts do tópico

=cut

sub _tpc_numero_posts {
    my ( $self, $element ) = @_;
    return $element->findvalue('.//td[4]');
}

=head2 _tpc_proxima_pagina_url

Retorna a url da próxima página que tem os tópicos o "next"

=cut

sub _tpc_proxima_pagina_url {
    my ( $self, $element ) = @_;
    my $url = $element->findnodes('//form/span[2]/a')->[-2];
    if ($url) {
        if ( $url->as_text =~ /next/ ) {

    # - Se tu retornar a url com esse "Main#", vai ter que fazer o login de novo
    #no Orkut, então tem que tira-lo.

            return $1 if $url->attr('href') =~ /Main#(.+)/;
        }
        return;
    }
}

=head2 _tpc_thread_all_itens

Pega todos os itens da thread.

=cut

sub _tpc_thread_all_itens {
    my ( $self, $thread_element ) = @_;
    return $thread_element->findnodes('//div[@class="listitem"]');
}

=head2 _tpc_thread_msg_nome

Retorna o nome da pessoa.

=cut

sub _tpc_thread_msg_nome {
    my ( $self, $thread_element_item ) = @_;
    my $nome = $thread_element_item->findnodes('.//h3/a')->[0];
    $nome ? return $nome->as_text : return 'null';
}

=head2 _tpc_thread_msg_nome_id

Retorna o ID de qm escreveu a menasgem.

=cut

sub _tpc_thread_msg_nome_id {
    my ( $self, $thread_element_item ) = @_;
    my $link_autor = $thread_element_item->findnodes('.//h3/a')->[0];
    if ($link_autor) {
        my $uri = URI::Query->new( $link_autor->attr('href') );
        return $uri->hash->{'/Main#Profile?uid'};
    }
    return 'null';
}

=head2 _tpc_thread_msg_texto

Retorna o texto da mensagem.

=cut

sub _tpc_thread_msg_texto {
    my ( $self, $thread_element_item ) = @_;
    my $msg = $thread_element_item->findnodes('.//div[@class="para"]')->[0];
    $msg ? return $msg->as_text : 'null';
}

=head2 _tpc_thread_proxima_pagina_url

Retorna o link da próxima página da thread.

=cut

sub _tpc_thread_proxima_pagina_url {
    my ( $self, $thread_element ) = @_;
    my $url = $thread_element->findnodes('//span[2]/a')->[-2];
    if ($url) {
        if ( $url->as_text =~ /next/ ) {
            return $1 if $url->attr('href') =~ /Main#(.+)/;
        }
    }
    return;
}

=head2 _busca_tpc_parser_itens

Pega todos os itens da busca.

=cut

sub _busca_tpc_parser_itens {
    my ( $self, $tpc_busca_element ) = @_;
    my $items = $tpc_busca_element->findnodes('//div[@class="listitem"]');
    @{$items} ? return $items : return;
}

=head2 _busca_tpc_parser_tpc_id

Faz o parser das buscas, recebe o HTML com o resultado da busca.
Retorna o ID da comunidade, ID do tópico e menasgens relacionadas a busca.

{
	id_comunidade => $id_comunidade,
	id_topico => $id_topico,
	titulo_tpc => $titulo_tpc,
	mensagens => [mensagem => $mensagem, link_mensagem => $link_mensagem],

}


=cut

sub _busca_tpc_parser_tpc_id {
    my ( $self, $tpc_busca_element_item ) = @_;

    my $struct;

    my $res = $tpc_busca_element_item->findnodes('.//a')->[0];
    if ($res) {

        # - O Orkut nao segue o RFC ou o módulo URI::Query está bugado,
        #então tem que retirar o começo da url do orkut com regexp...

        my $uri = $self->_clean_busca_url( $res->attr('href') );

        # - Agora pode usar como se deve usar, com URI::*

        my $tpc_nome = $res->as_text;
        $uri = URI::Query->new($uri);

        # - Construindo a estrutura dos dados.

        my $struct = {
            id_comunidade => $uri->hash->{'CommMsgs?cmm'},
            id_topico     => $uri->hash->{'tid'},
            titulo_tpc    => $res->as_text,
        };

        my @mensagens =
          $tpc_busca_element_item->findnodes('.//div[@class="para"]');

        foreach my $mensagem (@mensagens) {

            my $msg = $mensagem->as_text;
            my $link_msg =
              $self->_clean_busca_url(
                $mensagem->findnodes('.//a')->[0]->attr('href') );

            return unless $link_msg;

            push(
                @{ $struct->{'mensagens'} },
                {
                    mensagem => $msg,
                    link_msg => 'http://www.orkut.com/' . $link_msg,
                }
            );

        }
        return $struct;
    }
    return;
}

=head2 _clean_busca_url

Quando se faz uma busca o Orkut retorna na URL um monte de coisa que não
precisa e atrapalha, essa função limpa a url e pega só o necessário.

=cut

sub _clean_busca_url {
    my ( $self, $uri ) = @_;
    if ( URI::Escape::uri_unescape($uri) =~ /.+(CommMsgs.+)/ ) {
        return $1;
    }
    return;
}

1;
