#!/usr/bin/perl -w
# $Id: test.pl 292 2008-12-07 03:09:42Z pro $ $URL: svn://svn.setun.net/dcppp/trunk/test.pl $

=copyright
dev hub test
=cut
use strict;
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
use lib './lib';
use Net::DC::hub;
my $dc = Net::DC::hub->new();
$dc->work(100);
$dc->wait_finish();
$dc->disconnect();
#  $dc = undef;
