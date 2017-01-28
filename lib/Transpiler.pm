use strict;
use warnings;
use Switch;
package Transpiler;
sub err {
  die "Error: ".shift;
}

our $blockTargetPrefix = '$MAILDIR/';

our $out;
our %variables = (); #Declared variables, each caching a header value (e.g. From: in variable headerFrom)

our $inblock = 0; 
our @conditionsRaw = ();
our %conditionsVars = ();
our $blockTarget = "";


sub endblock(){
  if ($inblock) {
    $blockTarget or err "No => target";
    
    print $out "if (";
    foreach my $var (sort keys %conditionsVars) {
      push @conditionsRaw, "\$$var =~ /$conditionsVars{$var}/"
    }
    @conditionsRaw or err "No conditions";
    print $out (shift @conditionsRaw);
    foreach my $c (@conditionsRaw) {
      print $out " || ", $c;
    }
    print $out ")\n{\n";
    print $out "  to \"$blockTargetPrefix$blockTarget\"\n";
    print $out "}\n";
    $inblock = 0;
  }
}

sub makevariable{
  my $header = shift;
  my $var;
  my $mode = 0; #if the case should be changed
  #decide on variable name and header
  $var = "header$header"; 
  $var =~ s/([^A-Za-z_0-9])/"x".ord($1)/ge;
  #this can be used to match "Header:" case-sensitive and "header:" case-insensitive.
  #however, since maildrop defaults to case-insensitive and the performance does not matter much, it is probably pointless
  #switch ($header){
  #  case /^[A-Z]/ { 
  #    $var = "header$header"; 
  #    $mode = 0;
  #  }
  #  case /^[a-z]/ {
  #    $var = "lheader$header"; 
  #    $header =~ s/^([a-z])/uc $1/e;
  #    $mode = 1;
  #  }
  #  else { err "Invalid header"; }
  #}
  if (!$variables{$var}) {
    #declare variable for header. (only maildrop specific part of this sub)
    switch ($mode) {
      case 0 {
        print $out "/^$header:\\s*(.*)/\n";
        if ($header =~ /From|(Resent-)?To|(Resent-)?Cc/i) {
          print $out $var.'=getaddr("$MATCH1")'."\n";
        } else {
          print $out "$var=\"\$MATCH1\"\n";
          if ($header =~ /Subject/i) {
            print $out 'if ($headerSubject =~ /^=\?utf-8\?.*/)
{
  headerSubject=`reformime -h "$MATCH"`
}
';
          }
        }
      }
      case 1 {
        print $out $var.'=tolower("$'.makevariable($header).'")';
      }
      else { err "Internal error 123"; }
    }
    $variables{$var} = 1;
  }
  return $var;
}

sub process{
  my $in=shift;
  $out=shift;

  %variables = ();

  my $lastheader;
  
  while(my $line = <$in>) {
    $line =~ s/^\s+|\s+$//g;
    switch ($line) {
      case "{" {
        my $countopenparens = 1;
        while($line = <$in>) {
          if ($line =~ /^\s*\{\s*$/) { $countopenparens++ }
          elsif ($line =~ /^\s*\}\s*$/) { $countopenparens--; if ($countopenparens <= 0) { last; } }
          print $out $line;
        }
        if ($countopenparens > 0) { err 'Unclosed {'; }
        next;
      }
      case "" { endblock(); } 
      case /^=>(.+)/ { 
        $inblock or err "=> outside block";
        !$blockTarget or err "multiple =>";
        $line =~ /=>\s*(.*)/;
        $blockTarget = $1;
      }
      case /^\/|^\s*([A-Za-z0-9-]*)\s*:/ {
        #Open block
        if (!$inblock) {
          $inblock = 1;
          $lastheader = "";
          @conditionsRaw = ();
          %conditionsVars = ();
          $blockTarget = "";
        }
        if ($line =~ /^\//) { push @conditionsRaw, $line }
        else {
          $line =~ /^\s*([A-Za-z0-9_-]*)\s*:\s*(.*)/;
          my $value = $2;
          $1 or $lastheader or err "no header";
          $1 and $lastheader = $1;
          my $var = makevariable($lastheader);
          if ($value =~ /\s*\/(.*)\/\s*/) { $value = $1; }
          else { $value = quotemeta($value); } 
          if ($conditionsVars{$var}) { $conditionsVars{$var} = "$conditionsVars{$var}|($value)"; }
          else { $conditionsVars{$var} = "($value)"; }	
        }
      }
    } 
  }
  endblock();
  close $out;
}

1 