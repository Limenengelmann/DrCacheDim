#!/usr/bin/perl

@sizes = ();

# print possible cache sizes for the given parameter range

# L1
#for($i=6; $i<10; $i++) {
#    for($j=2; $j<16; $j++) {
# L2
for($i=7; $i<=10; $i++) {
    for($j=4; $j<=20; $j++) {
        $s = 2**$i * 64 * $j / 1024;
        push @sizes, $s;
        print "$s KB ($i x $j)\n" if $s == 256;
    }
}

@sorted = sort {$a <=> $b} @sizes;

foreach $i (@sorted){
    #print "$i KB\n";
}
