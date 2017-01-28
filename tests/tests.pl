#!/usr/bin/env perl
use strict;
use warnings;
use lib '../lib';
use lib 'lib';
use Transpiler;

our $pass = 0;
our $fail = 0;

sub test{
  my $in = shift;
  my $expected = shift;
  $expected =~ s/^\s+|\s+$//g;
  my $out = "";
    
  open my $infh, '<', \$in;
  open my $outfh, '>', \$out;
  
  Transpiler::process($infh, $outfh);
  $out =~ s/^\s+|\s+$//g;
  
  if ($out eq $expected) {
    print "test ok\n\n";
    $pass++;
  } else {
    print "test failed:\n";
    print "$in\n---------------->\n$out\n<--------------->\n$expected\n";
    print "\n\n\n";
    $fail++;
  }
}

my $common='to "$MAILDIR/"';

test("", $common);

test('
{
  foo bar
}', "  foo bar\n".$common);


test('/Subject: foo/
=> xyz', 'if (/Subject: foo/)
{
  to "$MAILDIR/xyz"
}
'.$common);

test('/Subject: foo/
/From: bar/
/Abcdef:\s*ghih/
=>123
', 'if (/Subject: foo/ || /From: bar/ || /Abcdef:\s*ghih/)
{
  to "$MAILDIR/123"
}
'.$common);

test('From:  /a|b|c/
Subject: alphabet...
=>    target
', '/^From:\s*(.*)/
headerFrom=getaddr("$MATCH1")
/^Subject:\s*(.*)/
headerSubject="$MATCH1"
if ($headerSubject =~ /^=\?utf-8\?.*/)
{
  headerSubject=`reformime -h "$MATCH"`
}
if ($headerFrom =~ /a|b|c/ || $headerSubject =~ /alphabet\.\.\./)
{
  to "$MAILDIR/target"
}
'.$common);


test('From:  /a|b|c/
=>    abc

From: foo
=> bar

From: xyz
=> def', 
'/^From:\s*(.*)/
headerFrom=getaddr("$MATCH1")
if ($headerFrom =~ /a|b|c/)
{
  to "$MAILDIR/abc"
}
if ($headerFrom =~ /foo/)
{
  to "$MAILDIR/bar"
}
if ($headerFrom =~ /xyz/)
{
  to "$MAILDIR/def"
}
'.$common);


test('To: a1
Cc: a2
Resent-To: a3
Resent-Cc: a4
Other: normal
=> a', '
/^To:\s*(.*)/
headerTo=getaddr("$MATCH1")
/^Cc:\s*(.*)/
headerCc=getaddr("$MATCH1")
/^Resent-To:\s*(.*)/
headerResentx45To=getaddr("$MATCH1")
/^Resent-Cc:\s*(.*)/
headerResentx45Cc=getaddr("$MATCH1")
/^Other:\s*(.*)/
headerOther="$MATCH1"
if ($headerCc =~ /a2/ || $headerOther =~ /normal/ || $headerResentx45Cc =~ /a4/ || $headerResentx45To =~ /a3/ || $headerTo =~ /a1/)
{
  to "$MAILDIR/a"
}
'.$common);


test(
'Test: abc
Test: def
Test: /foo|bar/
=> go
', 
'/^Test:\s*(.*)/
headerTest="$MATCH1"
if ($headerTest =~ /abc|def|foo|bar/)
{
  to "$MAILDIR/go"
}
to "$MAILDIR/"');


test('A: 123
&& B: 456
=> and', '
/^A:\s*(.*)/
headerA="$MATCH1"
/^B:\s*(.*)/
headerB="$MATCH1"
if (($headerA =~ /123/ && $headerB =~ /456/))
{
  to "$MAILDIR/and"
}
to "$MAILDIR/"
');

test('O: 0
A: 123
&& B: 4
&& : 5
&& : 6
X: ...
Y: ,,,
Z: !!!
=> test', '
/^O:\s*(.*)/
headerO="$MATCH1"
/^A:\s*(.*)/
headerA="$MATCH1"
/^B:\s*(.*)/
headerB="$MATCH1"
/^X:\s*(.*)/
headerX="$MATCH1"
/^Y:\s*(.*)/
headerY="$MATCH1"
/^Z:\s*(.*)/
headerZ="$MATCH1"
if (($headerA =~ /123/ && $headerB =~ /4/ && $headerB =~ /5/ && $headerB =~ /6/) || $headerO =~ /0/ || $headerX =~ /\.\.\./ || $headerY =~ /\,\,\,/ || $headerZ =~ /\!\!\!/)
{
  to "$MAILDIR/test"
}
to "$MAILDIR/"
');

test('A: 1
A: 2
: 3
: 4
=> a',
'/^A:\s*(.*)/
headerA="$MATCH1"
if ($headerA =~ /1|2|3|4/)
{
  to "$MAILDIR/a"
}
to "$MAILDIR/"');

test('O: 0
: +
=> a',
'/^O:\s*(.*)/
headerO="$MATCH1"
if ($headerO =~ /0|\+/)
{
  to "$MAILDIR/a"
}
to "$MAILDIR/"');

test('From: foo@example.org
: foo@example.com
: bar@example.org
=> exfolder',
'/^From:\s*(.*)/
headerFrom=getaddr("$MATCH1")
if ($headerFrom =~ /foo\@example\.org|foo\@example\.com|bar\@example\.org/)
{
  to "$MAILDIR/exfolder"
}
to "$MAILDIR/"
');


test('Subject: foo and bar
Subject: foo
&& From: /foo@|bar@/
=> foobar'
, '/^Subject:\s*(.*)/
headerSubject="$MATCH1"
if ($headerSubject =~ /^=\?utf-8\?.*/)
{
  headerSubject=`reformime -h "$MATCH"`
}
/^From:\s*(.*)/
headerFrom=getaddr("$MATCH1")
if (($headerSubject =~ /foo/ && $headerFrom =~ /foo@|bar@/) || $headerSubject =~ /foo\ and\ bar/)
{
  to "$MAILDIR/foobar"
}
to "$MAILDIR/"
');

print "score: $pass/".($pass+$fail)."\n";