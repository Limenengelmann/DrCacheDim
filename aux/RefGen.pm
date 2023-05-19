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

    my $fname = "$tmpdir/refgen-$size1-$reps1-$size2-$reps2-$size3-$reps3.asm";
    print "Generating '$fname'...\n";

    open my $fh, '>', $fname
        or die "[generate_code] Can't open '$fname': $!";

    my @asm = ();
    my $i  = 0;
    my $i1 = 0;
    my $i2 = 0;
    my $i3 = 0;
    for(my $r3=0; $r3<$reps3; $r3++) {
        for(my $r2=0; $r2<$reps2; $r2++) {
            for(my $r1=0; $r1<$reps1; $r1++) {
                $i = $i3 + $i2 + $i1;
                push @asm, "mov r10, [A+$i]";
                $i1 += 64;
                $i1 %= $size1;
            }
            $i2 += $size1;
            $i2 %= $size2;
        }
        $i3 += $size2;
        $i3 %= $size3;
    }

    my $refs = join("\n", @asm);
    my $code = qq" ; globals
                GLOBAL _start
                    
                ; constants
                SIZE3 equ $size3
                    
                SECTION .bss
                    align 64
                A:  resb    SIZE3
                    
                SECTION .text
                _start:
                    $refs
                    
                    mov rdi, 0
                    mov	eax, 60	    ; rax = syscall number
                    syscall         ; exit(rdi)";

    print $fh "$code";

    close $fh or die "[generate_code] Can't close '$fname': $!";

    print "Finished generating '$fname'\n";
    return $fname;
}

sub compile_code {
    my $fname = shift;
    my $objf = "$tmpdir/" . basename($fname) . ".o";
    my $outf = basename($fname);
    $outf =~ s/\.asm$//;
    $outf = "bin/" . $outf;

    print "Compiling '$fname'\n";
    system("nasm -Wall -felf64 -o $objf $fname") == 0 or die "[compile_code] Compililation failed: $!";
    system("ld -o $outf $objf") == 0 or die "[compile_code] Linking failed: $!";
    print "Finished compiling '$outf'\n";

    return $outf;
}

1;
