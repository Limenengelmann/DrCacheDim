package RefGen;

use strict;
use warnings;
use File::Temp qw/ tempfile /;
use File::Basename;

our $tmpdir = "/tmp/refgen";
system("mkdir $tmpdir") unless(-d $tmpdir);

sub generate_code {
    my $size1 = shift;
    my $reps1 = shift;
    my $size2 = shift;
    my $reps2 = shift;
    my $size3 = shift;
    my $reps3 = shift;

    my $p = "A";

    my $fname = "$tmpdir/refgen-$size1-$reps1-$size2-$reps2-$size3-$reps3.c";
    open my $fh, '>', $fname
        or die "[generate_code] Can't open '$fname': $!";

    #XXX: from https://gcc.gnu.org/onlinedocs/gcc/Extended-Asm.html
    #Do not expect a sequence of asm statements to remain perfectly consecutive after compilation, even when you are using the volatile qualifier. If certain instructions need to remain consecutive in the output, put them in a single multi-instruction asm statement.
    my $instr = '"movb (%0), %%r10b\\n\\t"';
    my $reps = 1e6;

    my @code = (qq'
        #include <stddef.h>
        #include <stdint.h>
        
        const size_t size1 = $size1;
        const size_t reps1 = $reps1;
        const size_t size2 = $size2;
        const size_t reps2 = $reps2;
        const size_t size3 = $size3;
        const size_t reps3 = $reps3;

        int64_t generate_memrefs(char* A){
            asm volatile(' . $instr x $reps . '
            :
            : "r" (A)
            : "r10", "memory");
            register int64_t t = 0;
    ');
    
    my $i  = 0;
    my $i1 = 0;
    my $i2 = 0;
    my $i3 = 0;
    for(my $r3=0; $r3<$reps3; $r3++) {
        for(my $r2=0; $r2<$reps2; $r2++) {
            for(my $r1=0; $r1<$reps1; $r1++) {
                $i = $i3 + $i2 + $i1;
                push @code, "t+=A[$i];\n";
                $i1 += 64;
                $i1 %= $size1;
            }
            $i2 += $size1;
            $i2 %= $size2;
        }
        $i3 += $size2;
        $i3 %= $size3;
    }
    print $fh "@code\nreturn t;}";

    close $fh or die "[generate_code] Can't close '$fname': $!";

    return $fname;
}

sub compile_code {
    my $fname = shift;
    my $objf = $fname =~ s/c$/o/r;
    my $outf = basename($fname);
    $outf =~ s/\.c$//;
    $outf = "bin/$outf";

    system("gcc -O0 $fname aux/refgen.c -o $outf") == 0 or die "[compile_code] Compililation failed: $!";

    return $outf;
}

1;
