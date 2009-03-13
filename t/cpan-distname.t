#!perl -w

use strict;
use Test;

plan tests => 195;

use ActiveState::CPAN::Utils qw(distname_info);

my $path;
my $info;

while (<DATA>) {
    next if /^\s*(#|$)/;
    chomp;
    if (/^(\S+)/) {
        $path = $1;
        print "# $path\n";
        $info = distname_info($path);
    }
    elsif (my($k, $v) = /^\s+(\w+):\s*(.*)/) {
        $v =~ s/\s+#.*//;
        undef($v) if $v eq "~";
        $k = "name" if $k eq "n";
        $k = "version" if $k eq "v";
        $k = "extension" if $k eq "ext";
        ok($info->{$k}, $v);
    }
    else {
        print "? $_\n";
    }
}

__DATA__

authors/id/G/GA/GAAS/libwww-perl-5.808.tar.gz
  name: libwww-perl
  version: 5.808
  maturity: released
  author: GAAS
  extension: tar.gz
  path: authors/id/G/GA/GAAS/libwww-perl-5.808.tar.gz

libwww-perl-5.808
  name: libwww-perl
  version: 5.808
  maturity: released
  author: ~
  extension:
  path: libwww-perl-5.808

authors/id/N/NI/NI-S/Tk800.024.tar.gz
  name: Tk
  version: 800.024
  author: NI-S
  extension: tar.gz

authors\id\U\UN\UNICOLET\Win32-TaskScheduler2.0.3.zip
  name: Win32-TaskScheduler
  version: 2.0.3
  extension: zip
  author: UNICOLET

authors\id\S\SM\SMANROSS\Win32-Exchange_v0.046a.tar.gz
  name: Win32-Exchange
  version: v0.046a
  extension: tar.gz
  author: SMANROSS

authors/id/M/MA/MARKLE/Apache2-Controller.tar.gz
  name: Apache2-Controller
  version:
  author: MARKLE

authors/id/M/MJ/MJFS/CGI/Base64-Serializer_0.1.tar.gz
  name: Base64-Serializer
  version: 0.1

authors\id\J\JO\JONG\Bioinf_V2.0.tar.gz
  name: Bioinf
  version: V2.0

authors/id/G/GW/GWORROLL/BitArray1-0.tar.gz
  name: BitArray
  version: 1-0

authors/id/A/AD/ADIRAJ/CGI-Widget-FilloutForm.tar.gz
  name: CGI-Widget-FilloutForm
  version:

authors/id/B/BL/BLADE/Class-CompiledC2.21.tgz
  name: Class-CompiledC
  version: 2.21

authors/id/H/HC/HCAMP/ESplit1.00.zip
  name: ESplit
  version: 1.00
  extension: zip

authors/id/I/IL/ILYAZ/modules/etext/etext.1.6.3.zip
  n: etext
  v: 1.6.3
  ext: zip

authors/id/P/PH/PHOENIXL/extensible_report_generator_1.13.zip
  n: extensible_report_generator
  v: 1.13
  ext: zip

authors/id/N/NH/NHARALE/File-ReadSimple.1.1.tar.gz
  n: File-ReadSimple
  v: 1.1
  ext: tar.gz

authors/id/M/MI/MITREHC/HoneyClient-Agent-0.98-stable.tar.gz
  n: HoneyClient-Agent
  v: 0.98-stable
  ext: tar.gz

authors/id/M/MI/MITREHC/HoneyClient-DB-0.98-stable.tar.gz
  n: HoneyClient-DB
  v: 0.98-stable
  ext: tar.gz

authors/id/C/CW/CWHITE/HPUX-LVM_0.06.tar.gz
  n: HPUX-LVM
  v: 0.06

authors/id/C/CW/CWHITE/HPUX-FS_0.05.tar.gz
  n: HPUX-FS
  v: 0.05

authors/id/G/GR/GRICHTER/HTTP-Webdav-0.1.18-0.17.1.tar.gz
  n: HTTP-Webdav
  v: 0.1.18-0.17.1

authors/id/S/SB/SBALA/jp_beta_1.tar.gz
  n: jp_beta   # TODO "jperl" "beta_1"
  v: 1

authors/id/T/TW/TWITTEK/konstrukt/Konstrukt-0.5-beta13.tar.gz
  n: Konstrukt
  v: 0.5-beta13

authors/id/D/DB/DBRIAN/Lingua-Wordnet0.73.tar.gz
  n: Lingua-Wordnet
  v: 0.73

authors/id/C/CH/CHARDIN/MailQuoteWrap0.01.tgz
  n: MailQuoteWrap
  v: 0.01

authors/id/P/PF/PFEIFFER/makepp-1.50-cvs-080517.tgz
  n: makepp
  v: 1.50-cvs-080517

authors/id/P/PF/PFEIFFER/makepp-1.50-cvs-070506.tgz
  n: makepp
  v: 1.50-cvs-070506

authors/id/H/HU/HUGHES/manish-db.tar.gz
  n: manish-db
  v:

authors/id/K/KU/KUNGFUFTR/Match-Any_0.03.tar.gz
  n: Match-Any
  v: 0.03

authors/id/H/HA/HAKANARDO/Math-Expr-LATEST.tar.gz
  n: Math-Expr
  v: LATEST

authors/id/M/MI/MICB/Mmap-a2.tar.gz
  n: Mmap
  v: a2

authors/id/Q/QU/QUATRIX/Nagios-Downtime.tar.gz
  n: Nagios-Downtime
  v:

authors/id/S/SE/SENGER/NET-IPFilter_V1.1.2.tar.gz
  n: NET-IPFilter
  v: V1.1.2

authors/id/S/SE/SENGER/NET-IPFilterSimple_V1.1.tar.gz
  n: NET-IPFilterSimple
  v: V1.1

authors/id/O/OR/ORCLEV/Net-BitTorrent-File-1.02-fix.tar.gz
  n: Net-BitTorrent-File
  v: 1.02-fix

authors/id/G/GO/GOMOR/Net-Frame-Layer-IPv6-1.01.tar.gz
  n: Net-Frame-Layer-IPv6
  v: 1.01

authors/id/D/DC/DCOPPIT/NewsClipper-1.32-OpenSource.tar.gz
  n: NewsClipper
  v: 1.32-OpenSource

authors/id/R/RI/RIK/NISPlus-0.06-alpha.tar.gz
  n: NISPlus
  v: 0.06-alpha

authors/id/A/AN/ANDYDUNC/Orac-alpha-1.2.6.tar.gz
  n: Orac
  v: alpha-1.2.6

authors/id/A/AN/ANDYDUNC/Orac-1.1.11.tar.gz
  n: Orac
  v: 1.1.11

authors/id/A/AN/ANDYDUNC/Orac-1.2.3.tar.gz
  n: Orac
  v: 1.2.3

authors/id/S/SM/SMEE/P4-3.5313.tar.gz
  n: P4
  v: 3.5313

authors/id/M/ME/MELONMAN/PDF-EasyPDF_0_04.tgz 
  n: PDF-EasyPDF
  v: 0_04

authors/id/E/EV/EVANZS/PDF-CreateSimple-1-1.tar.gz
  n: PDF-CreateSimple
  v: 1-1

authors/id/B/BM/BMIDD/perl5.00402-bindist04-msvcAlpha.tar.gz
  #n: perl    # TODO
  #v: 5.00402-bindist04-msvcAlpha

authors/id/S/SK/SKUNZ/perlmenu.v4.0.tar.gz
  n: perlmenu
  v: v4.0

authors\id\G\GB\GBOSS\perl_archie.1.5.tar.gz
  n: perl_archie
  v: 1.5

authors/id/S/SR/SREZIC/perl-pdf-0.06.1b-SREZIC-3.tar.gz
  n: perl-pdf
  v: 0.06.1b-SREZIC-3

authors/id/C/CW/CWEST/Pod-Simple-31337-0.02.tar.gz
  n: Pod-Simple-31337
  v: 0.02

authors\id\R\RF\RFOLEY\QNA_0.5.tar.gz
  n: QNA
  v: 0.5

authors\id\F\FE\FERNANDES\Reduziguais.zip
  n: Reduziguais
  v:
  ext: zip

authors/id/J/JE/JETTRA/RSS-Video-Google.tar.gz
  n: RSS-Video-Google
  v:

authors/id/S/SF/SFLEX/SF_form_secure/SF_form_secure_v4.0.tar.gz
  n: SF_form_secure
  v: v4.0

authors\id\T\TE\TEDK\Win32\SimpleProcess\SimpleProcess_1.0.zip
  n: SimpleProcess
  v: 1.0

authors/id/J/JW/JWHITE/SlideMap_1_2_2.tar.gz
  n: SlideMap
  v: 1_2_2

authors/id/B/BY/BYRNE/SOAP/SOAP-MIME-0.55-7.tar.gz
  n: SOAP-MIME
  v: 0.55-7
  ext: tar.gz

authors/id/J/JE/JESUS/Spread-3.17.3-1.07.tar.gz
  n: Spread
  v: 3.17.3-1.07

authors/id/R/RC/RCALEY/speech_pm_1.0.tgz
  n: speech_pm
  v: 1.0

authors/id/C/CA/CARPENTER/Storm-Tracker_0.02.tar.gz
  n: Storm-Tracker
  v: 0.02

authors/id/E/EX/EXODIST/lsce/String-lcse-0.1-r2.tar.gz
  n: String-lcse
  v: 0.1-r2

authors/id/M/MI/MIKO/String-Util-0-11.tar.gz
  n: String-Util
  v: 0-11

authors\id\S\SI\SIMATIKA\subclustv1_0.tar.gz
  n: subclust
  v: v1_0

authors\id\L\LI\LISCOVIUS\SWF-0.4.0-beta6_02.tar.gz
  n: SWF
  v: 0.4.0-beta6_02

authors\id\G\GA\GABOR\Text-Format0.52+NWrap0.11.tar.gz
  n: Text-Format0.52+NWrap  # No sane way with this one :-(
  v: 0.11

authors\id\G\GA\GABOR\Text-Format0.52.tar.gz
  n: Text-Format
  v: 0.52

authors/id/H/HA/HARRY/Text-Convert-ToImage.tgz
  n: Text-Convert-ToImage
  v:
  ext: tgz

authors/id/R/RH/RHASE/Tivoli_0.01.tar.gz
  n: Tivoli
  v: 0.01

authors/id/J/JH/JHIVER/Unicode-Transliterate.0.3.tgz
  n: Unicode-Transliterate
  v: 0.3
  
authors/id/D/DO/DODGER/WebPresence/WebPresence-Profile.tar.gz
  n: WebPresence-Profile
  v:

authors/id/S/SE/SENGER/WordPress-V1.zip
  n: WordPress
  v: V1

authors\id\S\SE\SENGER\WWW-GameStar_V1.2.tar.gz
  n: WWW-GameStar
  v: V1.2

authors/id/S/SE/SENGER/WWW-Heise_V1.2.tar.gz
  n: WWW-Heise
  v: V1.2

authors/id/S/SE/SENGER/WWW-CpanRecent_V1.0.tar.gz
  n: WWW-CpanRecent
  v: V1.0

authors/id/S/SE/SENGER/WWW-Newsgrabber_V1.0.tar.gz
  n: WWW-Newsgrabber
  v: V1.0

authors\id\J\JA\JASONS\XML-Xerces-1.7.0-1.tar.gz
  n: XML-Xerces
  v: 1.7.0-1

authors/id/J/JA/JASONS/XML-Xerces-2.7.0-0.tar.gz
  n: XML-Xerces
  v: 2.7.0-0

authors/id/D/DY/DYACOB/Zobel-0.20-100701.tar.gz
  n: Zobel
  v: 0.20-100701
  author: DYACOB

RSOLIV/mysql-genocide_0.01.tar.gz
  n: mysql-genocide
  v: 0.01
  author: RSOLIV

DJPADZ/finance-yahooquote_0.19.tar.gz
  n: finance-yahooquote
  v: 0.19
  author: DJPADZ

EIKEG/doc/perl-tutorial_1.0.tar.gz
  n: perl-tutorial
  v: 1.0
  author: EIKEG

TIMB/perl5.004_04.tar.gz
  n: perl
  v: 5.004_04
  author: TIMB

Foo-Bar
  name: Foo-Bar
  version:
  author: ~
  ext:

G/GA/GAAS/mylib-1.02.tar.gz
  name: mylib
  version: 1.02
  author: GAAS
  ext: tar.gz
