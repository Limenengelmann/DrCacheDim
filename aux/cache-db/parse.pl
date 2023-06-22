#!/usr/bin/perl -w

use strict;
use warnings;

sub toKB {
    my $s = shift || return 0;
    my $unit = shift || return 0;

    if ($unit eq "KB") {
        return $s;
    } elsif ($unit eq "MB") {
        return $s*1024;
    } 
}

my @files = <./sites/*>;
my $outp = [];
#open my $outf, ">", "output.txt";
# collect relevant lines of the html
foreach my $file (@files) {
    #print $file . "\n";
    open my $fh, "<", $file;
    my $state = 0;
    my $cpus = [];
    while (my $l = <$fh>) {
        if ($state == 0) {
            $state = 1 if $l =~ 'id="sys-spec"';
            next;
        }
        if ($state == 1) {
            $state = 2 if $l =~ 'Cache' or $l =~ "CPU Name";
        }
        if ($state >= 2) {
            #print $outf $l;
            push @$cpus, $l;
            $state++;
        }
        if ($state > 3) {
            $state = 1;
        }
    }
    push @$outp, $cpus;
    #last;
}

#open my $outf, "<", "output.txt";
#close $outf;

foreach my $cpu (@$outp) {
    my $name = "";
    my $size0 = 0;
    my $ways0 = 0;
    my $size1 = 0;
    my $ways1 = 0;
    my $size2 = 0;
    my $ways2 = 0;
    my $size3 = 0;
    my $ways3 = 0;

    my $state = 0;
    my $unit = "";
    while (my $l = shift @$cpu) {
        if ($l =~ ">CPU Name<") {
            $l = shift @$cpu;
            ($name) = $l =~ />(.*)</;
        } elsif ($l =~ ">Caches<") {
            $l = shift @$cpu;
            ($size1, $unit) = $l =~ /L1D\s*:\s*(\d+)\s*(\w+)\s*/;
            $size1 = toKB $size1, $unit;
            ($size2, $unit) = $l =~ /L2\s*:\s*(\d+)\s*(\w+)\s*/;
            $size2 = toKB $size2, $unit;
            ($size3, $unit) = $l =~ /L3\s*:\s*(\d+)\s*(\w+)\s*/;
            $size3 = toKB $size3, $unit;
        } elsif ($l =~ ">Caches Assoc.<") {
            $l = shift @$cpu;
            ($ways1) = $l =~ /L1D\s*:\s*(\d+)-way/;
            ($ways2) = $l =~ /L2\s*:\s*(\d+)-way/;
            ($ways3) = $l =~ /L3\s*:\s*(\d+)-way/;
        } elsif ($l =~ ">L1 Inst. Cache<") {
            #<div class="cell">1.25 MB (10-way, 64-byte line)</div>
            $l = shift @$cpu;
            next if $l =~ ">-<";
            ($size0, $unit, $ways0) = $l =~ /([.\d]+) (\w+) \((\d+)-way/;
            $size0 = toKB $size0, $unit;
        } elsif ($l =~ ">L1 Data Cache<") {
            $l = shift @$cpu;
            next if $l =~ ">-<";
            ($size1, $unit, $ways1) = $l =~ /([.\d]+) (\w+) \((\d+)-way/;
            $size1 = toKB $size1, $unit;
        } elsif ($l =~ ">L2 Cache<") {
            $l = shift @$cpu;
            next if $l =~ ">-<";
            ($size2, $unit, $ways2) = $l =~ /([.\d]+) (\w+) \((\d+)-way/;
            $size2 = toKB $size2, $unit;
        } elsif ($l =~ ">L3 Cache<") {
            $l = shift @$cpu;
            next if $l =~ ">-<";
            ($size3, $unit, $ways3) = $l =~ /([.\d]+) (\w+) \((\d+)-way/;
            $size3 = toKB $size3, $unit;
        }
    }
    # transform to sets
    defined $size0 and defined $ways0 and $size0 > 0 and $ways0 > 0 ? $size0 = $size0*1024 / 64 / $ways0 : 0;
    defined $size1 and defined $ways1 and $size1 > 0 and $ways1 > 0 ? $size1 = $size1*1024 / 64 / $ways1 : 0;
    defined $size2 and defined $ways2 and $size2 > 0 and $ways2 > 0 ? $size2 = $size2*1024 / 64 / $ways2 : 0;
    defined $size3 and defined $ways3 and $size3 > 0 and $ways3 > 0 ? $size3 = $size3*1024 / 64 / $ways3 : 0;
    
    #printf "id: %s, L1I: %5d KB, %2d w, L1D: %5d KB, %2d w, L2: %5d KB, %2d w, L3: %6d KB, %2d w\n"
    #    ,$name , $size0, $ways0, $size1, $ways1, $size2, $ways2, $size3, $ways3;
    next if not defined $ways3 or not defined $ways2 or not defined $size2 or not defined $size3;
    printf "L1I: %5d KB, %2d w, L1D: %5d KB, %2d w, L2: %5d KB, %2d w, L3: %6d KB, %2d w\n"
        ,$size0, $ways0, $size1, $ways1, $size2, $ways2, $size3, $ways3;

    #print("$name\n");
}
