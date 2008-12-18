#!/usr/bin/perl -w
use strict;
use Module::Build;

my $build = Module::Build->new(
    module_name => 'Net::DirectConnect',
    license  => 'perl',
    Sswcreate_makefile_pl => 'traditional',
    create_makefile_pl => 'small',

);
$build->create_build_script;
