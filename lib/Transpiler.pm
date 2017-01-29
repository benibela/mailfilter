use strict;
use warnings;
use Switch;
package Transpiler;
sub err {
  die "Error: ".shift;
}

our $blockTargetPrefix = '$MAILDIR/.';

our $out;
our %variables = (); #Declared variables, each caching a header value (e.g. From: in variable headerFrom)

our $inblock = 0; 
our @conditions = (); #conditions for the current filter block. pairs (name, value) for most tested headers, (name1, value1, name2, value2, ...) for && conditions
our @conditionsForMark = (); 
our $blockTarget = "";
our $hadDefaultBlock = 0;
our $markRead = 0;

sub printconditions{
  my $conditions = shift; 
  my @conditions = @$conditions;
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
}

sub endblock(){
  if ($inblock) {
    $blockTarget or err "No => target";
    !$hadDefaultBlock or err "Block after unconditional => block";

    my $target = $blockTargetPrefix.$blockTarget;
    
    if (@conditions) {
      print $out "if (";
      printconditions (\@conditions);
      print $out ")\n{\n";
      print $out "  ".($markRead?"cc":"to")." \"$target\"\n";
      if ($markRead) {
        my $indent = "  ";
        if (@conditionsForMark) {
          print $out "  if (";
          printconditions (\@conditionsForMark);
          print $out ")\n  {\n";
          $indent = "    ";
        }
        print $out $indent."`ls -t $target/new | head -1 | xargs -I {} mv '$target/new/{}' '$target/cur/{}:2,S'`\n";
        print $out "  }\n" if (@conditionsForMark);
        print $out "  exit\n";
      } else {
        !@conditionsForMark or err "conditions after =>";
      }
      print $out "}\n";
    } else {
      $hadDefaultBlock = 1;
      print $out "to \"$target\"\n";
    }    
    $inblock = 0;
    
    $blockTarget = "";
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

sub startblock(){
  $inblock = 1;
  @conditions = ();
  @conditionsForMark = ();
  $markRead = 0;
  $blockTarget = "";
}

sub process{
  my $in=shift;
  $out=shift;

  %variables = ();
  $hadDefaultBlock = 0;

  my $lastheader;
  my $lastConditions;
  
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
        last;
      }
      case "" { endblock(); } 
      case /^=>(.+)/ { 
        if (!$inblock) {
           !$hadDefaultBlock or err "=> outside block";
           startblock;
        }
        !$blockTarget or err "multiple =>";
        $line =~ /=>\s*(.*)/;
        $blockTarget = $1;
        $inblock = 1;
        $lastConditions = \@conditionsForMark;
      }
      case /^(&&)?\s*(\/|([A-Za-z0-9-]*)\s*:)/ {
        #Open block
        if (!$inblock) {
          startblock();
          $lastConditions = \@conditions;
          $lastheader = "";
        }
        my @newFilter = ();
        my $andFilter = 0;
        if ($line =~ /^&&/) {
          $andFilter = 1;
          $line =~ s/^&&//;
        }
        if ($line =~ /^\//) { 
          @newFilter = ("", $line); 
          if ($line =~ /^\/(.*)\/[hbD]*$/) {
            my $pattern = $1;
            eval { qr/$1/ };
            err "Invalid regex: $line" if ($@);
          } else {
            err "Regex does not end with trailing slash / flags: $line ";
          }
        } else {
          $line =~ /^\s*([A-Za-z0-9_-]*)\s*:\s*(.*)/;
          my $value = $2;
          $1 or $lastheader or err "no header";
          $1 and $lastheader = $1;
          my $var = makevariable($lastheader);
          if ($value =~ /\s*\/(.*)\/\s*/) { $value = $1; }
          else { 
            my $prefix = ""; my $suffix = "";
            $value =~ s/^\^/$prefix='^\s*',""/e;
            $value =~ s/\$$/$suffix='\s*$',""/e;
            $value = $prefix.quotemeta($value).$suffix; 
          } 
          @newFilter = ($var, $value);
        }
        if ($andFilter) {
          push @{$$lastConditions[@$lastConditions - 1]}, @newFilter;
        } else {
          push @$lastConditions, \@newFilter
        }
      }
      case /^mark\s+read$/ {
        $blockTarget or err "mark without preceding =>";
        $markRead = 1;
      }
      else { err "unexpected line: $line"; }
    } 
  }
  endblock();
  
  if (!$hadDefaultBlock) {
      print $out "to \"$blockTargetPrefix\"\n";
  }
  
  close $out;
}

1 