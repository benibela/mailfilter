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
our @conditions = (); #conditions for the current filter block. pairs (name, value) for most tested headers, (name1, value1, name2, value2, ...) for && conditions
our $blockTarget = "";
our $hadDefaultBlock = 0;

sub endblock(){
  if ($inblock) {
    $blockTarget or err "No => target";
    !$hadDefaultBlock or err "Block after unconditional => block";
    
    print $out "if (";
    if (@conditions) {
      my %pairMerging = ();
      my @newConditions = ();
      foreach my $c (@conditions) {
        my @cur = @$c;
        if (@cur == 2 && $cur[0] ne "") {
          if (exists $pairMerging{$cur[0]}) { $pairMerging{$cur[0]} = $pairMerging{$cur[0]} . "|" . $cur[1]; }
          else { $pairMerging{$cur[0]} = $cur[1]; }
        } else { push @newConditions, $c; }
      }
      foreach my $var (sort keys %pairMerging) {
        push @newConditions, ["", "\$$var =~ /$pairMerging{$var}/" ];
      }
      my $first = 1;
      foreach my $c (@newConditions) {
        $first or print $out " || ";
        $first = 0;
        my @cur = @$c;
        if ($cur[0] eq "") {
          print $out $cur[1];
        } elsif (@cur == 2) {
          err "internal error 230: ".join(@cur, ", ");
        } else {
          print $out "(";
          foreach my $i (0 .. @cur / 2 - 1) {
            $i == 0 || print $out " && ";
            my $j = 2*$i;
            if ($cur[$j] eq "") { print $out $cur[$j + 1]; }
            else { print $out "\$$cur[$j] =~ /$cur[$j+1]/"; }
          }
          print $out ")"; 
        }        
      }
      print $out ")\n{\n";
      print $out "  to \"$blockTargetPrefix$blockTarget\"\n";
      print $out "}\n";
    } else {
      $hadDefaultBlock = 1;
      print $out "  to \"$blockTargetPrefix$blockTarget\"\n";
    }    
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
  $hadDefaultBlock = 0;

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
      case /^(&&)?\s*(\/|([A-Za-z0-9-]*)\s*:)/ {
        #Open block
        if (!$inblock) {
          $inblock = 1;
          $lastheader = "";
          @conditions = ();
          $blockTarget = "";
        }
        my @newFilter = ();
        my $andFilter = 0;
        if ($line =~ /^&&/) {
          $andFilter = 1;
          $line =~ s/^&&//;
        }
        if ($line =~ /^\//) { @newFilter = ("", $line); }
        else {
          $line =~ /^\s*([A-Za-z0-9_-]*)\s*:\s*(.*)/;
          my $value = $2;
          $1 or $lastheader or err "no header";
          $1 and $lastheader = $1;
          my $var = makevariable($lastheader);
          if ($value =~ /\s*\/(.*)\/\s*/) { $value = $1; }
          else { $value = quotemeta($value); } 
          @newFilter = ($var, $value);
        }
        if ($andFilter) {
          my $ref = $conditions[@conditions - 1];
          my @temp = @$ref;
          push @temp, @newFilter;
          $conditions[@conditions - 1] = \@temp;
        } else {
          push @conditions, \@newFilter
        }
      }
    } 
  }
  endblock();
  
  if (!$hadDefaultBlock) {
      print $out "to \"$blockTargetPrefix\"\n";
  }
  
  close $out;
}

1 