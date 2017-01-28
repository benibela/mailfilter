#!/usr/bin/env perl
use strict;
use warnings;
use lib 'lib';
use Transpiler;


 
Transpiler::process(*STDIN, *STDOUT)