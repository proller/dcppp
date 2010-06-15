use ExtUtils::MakeMaker;
#See lib/ExtUtils/MakeMaker.pm for details of how to influence
#the contents of the Makefile that is written.
%_ = (
  NAME         => 'Net::DirectConnect',
  VERSION_FROM => 'lib/Net/DirectConnect.pm',
  INSTALLDIRS  => 'site',
  PREREQ_PM    => {
    'Time::HiRes'         => 0,
    'MIME::Base32'        => 0,    #for adc only
    'Sys::Sendfile'       => 0,    #faster file sending
    'IO::Compress::Bzip2' => 0,    #preparing filelists
    'DBI'                 => 0,
    'DBD::SQLite'         => 0,
  },
);
$_{dist} = {
  PREOP    => "pod2text $_{VERSION_FROM} | tee README >\$(DISTVNAME)/README; chmod -R u=rwX,go=rX . ;",
  COMPRESS => 'gzip -9v',
  SUFFIX   => '.gz',
};
$_{PREREQ_PM}{'Net::DirectConnect::TigerHash'} = 0,    #for sharing and adc
  $_{NORECURS} = 1, if $^O =~ /win32/i or $^O =~ /mswin/ or $^O =~ /freebsd/i;
WriteMakefile(%_);

sub MY::postamble {
  qq{

#docs: README

#README: $_{VERSION_FROM}
#pod2text $_{VERSION_FROM} > README

fullclean: distclean veryclean
	rm -f \$(DISTNAME)-*.tar.gz *.bak *.old *.core MANIFEST README

release: fullclean manifest metafile dist
}
}
