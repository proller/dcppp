# New ports collection makefile for:	p5-Net-DirectConnect
# Date created:		2010-01-16
# Whom:			Oleg Alexeenkov <proler@gmail.com>
#
# $FreeBSD: ports/net-p2p/p5-Net-DirectConnect/Makefile,v 1.9 2012/05/28 09:14:34 culot Exp $
#

PORTNAME=	Net-DirectConnect
PORTVERSION=	0.13
CATEGORIES=	net-p2p net perl5
MASTER_SITES=	CPAN
PKGNAMEPREFIX=	p5-

MAINTAINER=	proler@gmail.com
COMMENT=	Perl Direct Connect lib and client

LICENSE=	ART10 GPLv1
LICENSE_COMB=	dual

BUILD_DEPENDS=	p5-DBD-SQLite>=0:${PORTSDIR}/databases/p5-DBD-SQLite \
		p5-DBI>=0:${PORTSDIR}/databases/p5-DBI \
		p5-IO-Socket-INET6>=0:${PORTSDIR}/net/p5-IO-Socket-INET6 \
		p5-IO-Socket-IP>=0:net/p5-IO-Socket-IP \
		p5-IO-Socket-SSL>=0:${PORTSDIR}/security/p5-IO-Socket-SSL \
		p5-Net-DirectConnect-TigerHash>=0:${PORTSDIR}/net-p2p/p5-Net-DirectConnect-TigerHash \
		p5-lib-abs>=0:${PORTSDIR}/devel/p5-lib-abs \
		p5-MIME-Base32>=0:${PORTSDIR}/converters/p5-MIME-Base32 \
		p5-Sys-Sendfile-FreeBSD>=0:${PORTSDIR}/devel/p5-Sys-Sendfile-FreeBSD
#		p5-Socket6>=0:${PORTSDIR}/net/p5-Socket6 \
RUN_DEPENDS:=	${BUILD_DEPENDS}

PERL_CONFIGURE=	yes

MAN1=		dcget.1 dcshare.1
MAN3=		Net::DirectConnect.3 Net::DirectConnect::filelist.3

.include <bsd.port.pre.mk>

.if ${PERL_LEVEL} < 501001
BUILD_DEPENDS+=	p5-IO-Compress>=0:${PORTSDIR}/archivers/p5-IO-Compress
RUN_DEPENDS+=	p5-IO-Compress>=0:${PORTSDIR}/archivers/p5-IO-Compress
.endif

.include <bsd.port.post.mk>
