#Copyright (C) 2005-2006 Oleg Alexeenkov http://sourceforge.net/projects/dcppp proler@gmail.com icq#89088275
my $Id = '$Id$';
# reserved for future 8)
package dcppp::hubcli;
use dcppp;
use strict;
no warnings qw(uninitialized);
our $VERSION = ( split( ' ', '$Revision$' ) )[1];
#our @ISA = ('dcppp');
use base 'dcppp';

sub init {
  my $self = shift;
  %$self = (
    %$self,
    #
    , @_
  );
  $self->baseinit();
  $self->get_peer_addr();
  $self->{'log'}->( 'info', "[$self->{'number'}] Incoming client $self->{'host'}:$self->{'port'}" ) if $self->{'incoming'};
  $self->{'parse'} ||= {
    'Supports' => sub {
      #      $self->supports_parse( $_[0], $self->{'NickList'}->{ $self->{'peernick'} } );
      $self->supports_parse( $_[0], $self->{'peer_supports'} );
    },
    'Key' => sub {
    },
    'ValidateNick' => sub {
      return $self->cmd('ValidateDenide') if exists $self->{'NickList'}->{ $_[0] };
      $self->{'peer_nick'}                          = $_[0];
      $self->{'NickList'}->{ $self->{'peer_nick'} } = $self->{'peer_supports'};
      $self->{'status'}                             = 'connected';
      $self->cmd('Hello');
    },
    'Version' => sub {
      $self->{'NickList'}{ $self->{'peer_nick'} }{'Version'} = $_[0];
    },
    'GetNickList' => sub {
      $self->cmd('NickList');
      $self->cmd('OpList');
    },
    'MyINFO' => sub {
      my ( $nick, $info ) = $_[0] =~ /\S+\s+(\S+)\s+(.*)/;
      #        print("Bad nick:[$_[0]]"), return unless length $nick;
      return if $nick ne $self->{'peer_nick'};
      $self->{'NickList'}->{$nick}{'Nick'} = $nick;
      #        $self->{'NickList'}->{$nick}{'info'} = $info;
      #print "preinfo[$info] to $self->{'NickList'}->{$nick}\n";
      $self->info_parse( $info, $self->{'NickList'}{$nick} );
      $self->{'NickList'}->{$nick}{'online'} = 1;
      #        print  "info:$nick [$info]\n";
    },
    'GetINFO' => sub {
      my $to = shift;
    },
    'chatline' => sub {
      $self->{'parent'}->rcmd( 'chatline', @_ );
    },
  };
  $self->{'cmd'} ||= {
    'Lock' => sub {
      $self->sendcmd( 'Lock', $self->{'Lock'} );
    },
    'HubName' => sub {
      $self->sendcmd( 'HubName', $self->{'HubName'} );
    },
    'ValidateDenide' => sub {
      $self->sendcmd('ValidateDenide');
    },
    'Hello' => sub {
      $self->sendcmd( 'Hello', $self->{'peer_nick'} );
    },
    'NickList' => sub {
      $self->sendcmd( 'NickList', join '$$', grep { !$self->{'NickList'}{$_}{'oper'} } keys %{ $self->{'NickList'} } );
    },
    'OpList' => sub {
      $self->sendcmd( 'OpList', join '$$', grep { $self->{'NickList'}{$_}{'oper'} } keys %{ $self->{'NickList'} } );
    },
  };
  $self->{'sendbuf'} = 1;
  $self->cmd('Lock');
  $self->{'sendbuf'} = 0;
  $self->cmd('HubName');
}
1;
