# New ports collection makefile for:	p5-Net-DirectConnect
# Date created:		2010-01-16
# Whom:			Oleg Alexeenkov <proler@gmail.com>
#
# $FreeBSD$
#

PORTNAME=	Net-DirectConnect
PORTVERSION=	0.06
CATEGORIES=	net-p2p net perl5
MASTER_SITES=	CPAN
PKGNAMEPREFIX=	p5-

MAINTAINER=	proler@gmail.com
COMMENT=	Perl Direct Connect lib and client.

RUN_DEPENDS=	p5-MIME-Base32>=0:${PORTSDIR}/converters/p5-MIME-Base32 \
		p5-Sys-Sendfile-FreeBSD>=0:${PORTSDIR}/devel/p5-Sys-Sendfile-FreeBSD \
		p5-Net-DirectConnect-TigerHash>=0:${PORTSDIR}/net-p2p/p5-Net-DirectConnect-TigerHash

PERL_CONFIGURE=	yes

.include <bsd.port.pre.mk>
.include <bsd.port.post.mk>
