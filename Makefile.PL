use ExtUtils::MakeMaker;
#See lib/ExtUtils/MakeMaker.pm for details of how to influence
#the contents of the Makefile that is written.
%_ = (
  NAME         => 'Net::DirectConnect',
  VERSION_FROM => 'lib/Net/DirectConnect.pm',    # finds $VERSION
  INSTALLDIRS  => 'site',
  PREREQ_PM    => {
    'Time::HiRes'  => 0,
    'MIME::Base32' => 0,                         #for adc only
    'Net::DirectConnect::TigerHash' => 0,
  },
  NORECURS => 1,


);

$_{dist}= {
	            PREOP	=> "pod2text $_{VERSION_FROM} | tee README >\$(DISTVNAME)/README; chmod -R u=rwX,go=rX . ;",
	            COMPRESS	=> 'gzip -9v',
	            SUFFIX	=> '.gz',
	           };

WriteMakefile(%_);

sub NONONO_MY::postamble {
  qq{

#docs: README

#README: $_{VERSION_FROM}
#	pod2text $_{VERSION_FROM} > README

fullclean: distclean veryclean
	rm -f \$(DISTNAME)-*.tar.gz *.bak *.old MANIFEST README

release: fullclean manifest metafile dist
}
}
