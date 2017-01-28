#!/usr/bin/env perl
use strict;
use warnings;
use lib '../lib';
use lib 'lib';
use Transpiler;

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
  } else {
    print "test failed:\n";
    print "$in\n---------------->\n$out\n<--------------->\n$expected\n";
    print "\n\n\n";
  }
}

test("", "");

test('
{
  foo bar 
}', "  foo bar");


test('/Subject: foo/
=> xyz', 'if (/Subject: foo/)
{
  to "$MAILDIR/xyz"
}');

test('/Subject: foo/
/From: bar/
/Abcdef:\s*ghih/
=>123
', 'if (/Subject: foo/ || /From: bar/ || /Abcdef:\s*ghih/)
{
  to "$MAILDIR/123"
}');

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
if ($headerFrom =~ /(a|b|c)/ || $headerSubject =~ /(alphabet\.\.\.)/)
{
  to "$MAILDIR/target"
}');


test('From:  /a|b|c/
=>    abc

From: foo
=> bar

From: xyz
=> def', 
'/^From:\s*(.*)/
headerFrom=getaddr("$MATCH1")
if ($headerFrom =~ /(a|b|c)/)
{
  to "$MAILDIR/abc"
}
if ($headerFrom =~ /(foo)/)
{
  to "$MAILDIR/bar"
}
if ($headerFrom =~ /(xyz)/)
{
  to "$MAILDIR/def"
}');


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
if ($headerCc =~ /(a2)/ || $headerOther =~ /(normal)/ || $headerResentx45Cc =~ /(a4)/ || $headerResentx45To =~ /(a3)/ || $headerTo =~ /(a1)/)
{
  to "$MAILDIR/a"
}
');