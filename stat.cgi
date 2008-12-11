use strict;
eval { use Time::HiRes qw(time sleep); };
#use lib './lib';
#use dcppp::clihub;
use Data::Dumper;    #dev only
$Data::Dumper::Sortkeys = 1;
#use DBI;
our %config;
do 'stat.pl';
use lib qw(./pslib ./../pslib ./../../pslib);
use pssql;
use psmisc;
use psweb;
psmisc::config();
