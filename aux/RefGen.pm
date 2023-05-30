package RefGen;

use strict;
use warnings;
use File::Temp qw/ tempfile /;
use File::Basename;

our $tmpdir = "/tmp/refgen";
system("mkdir $tmpdir") unless(-d $tmpdir);

sub capway_code {
    my $H = shift;

    my $size1 = $H->{L1D}->{cfg}->{size};
    my $ways1 = $H->{L1D}->{cfg}->{assoc};
    my $size2 = $H->{L2}->{cfg}->{size};
    my $ways2 = $H->{L2}->{cfg}->{assoc};
    my $size3 = $H->{L3}->{cfg}->{size};
    my $ways3 = $H->{L3}->{cfg}->{assoc};

    my $sets1 = $size1 / $ways1 / 64;
    my $sets2 = $size2 / $ways2 / 64;
    my $sets3 = $size3 / $ways3 / 64;

    my $fname = "$tmpdir/capway-$size1-$ways1-$size2-$ways2-$size3-$ways3.asm";
    print "Generating '$fname'...\n";
    open my $fh, '>', $fname
        or die "[generate_code] Can't open '$fname': $!";

    my $stride1 = 1;
    my $stride2 = 1;
    my $stride3 = $size3;

    my $code = qq"
                ; globals
                GLOBAL _start

                ; constants
                SIZE1 equ $size1
                SIZE2 equ $size2
                SIZE3 equ $size3

                SETS1 equ $sets1
                SETS2 equ $sets2
                SETS3 equ $sets3

                WAYS1 equ $ways1
                WAYS2 equ $ways2
                WAYS3 equ $ways3

                ; SIZE3*assoc3 so we can access the same tags in a direct mapped cache of the same capacity
                GSIZE equ SIZE3*WAYS3   ;TODO: handle non-powers of 2 ways

                STRIDE1 equ $stride1
                STRIDE2 equ $stride2
                STRIDE3 equ $stride3

                SECTION .bss
                    align 64
                A:  resb    GSIZE
                    
                SECTION .text
                _start:

                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                ;L1:
                ;.loop:
                ;    mov r10, [A+eax]
                ;    add eax, STRIDE1
                ;    cmp eax, SIZE1
                ;    jl loop
                ;    mov eax, 0
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                ;L2_1:
                ;    mov r10, [A+eax]
                ;    add eax, STRIDE2
                ;    cmp eax, SIZE2
                ;    jl L2_1
                ;
                ;    mov eax, 0
                ;L2_2:
                ;    mov r10, [A+eax]
                ;    add eax, STRIDE2
                ;    cmp eax, SIZE2
                ;    jl L2_2
                ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
                    mov rdi, 0  ;repeats counter
                L3:
                    lea rax, A  ;base
                .loop2:
                    mov rsi, 0  ;offset
                .loop1:
                    mov cl, [rax + rsi]

                    add rsi, 64
                    cmp rsi, 64*SETS3
                    jl .loop1

                    add rax, SIZE3
                    cmp rax, A+GSIZE
                    jl .loop2

                    ; repeat once
                    add rdi, 1
                    cmp rdi, 2
                    jl L3

                    ; exit
                    mov rdi, 0
                    mov	rax, 60	    ; rax = syscall number
                    syscall         ; exit(rdi)
                    ";

    print $fh "$code";

    close $fh or die "[generate_code] Can't close '$fname': $!";

    print "Finished generating '$fname'\n";
    return $fname;
}

sub optimal_code {
    my $size1 = shift;
    my $size2 = shift;
    my $size3 = shift;
    my $fname = "$tmpdir/optgen-$size1-$size2-$size3.asm";
    print "Generating '$fname'...\n";
    open my $fh, '>', $fname
        or die "[generate_code] Can't open '$fname': $!";

    my $code = qq" ; globals
                GLOBAL _start

                ; constants
                SIZE3 equ $size3
                SIZE2 equ $size2
                SIZE1 equ $size1
                    
                SECTION .bss
                    align 64
                A:  resb    SIZE3
                    
                SECTION .text
                _start:
                    ; L1 pass
                    mov eax, 0
                L1:
                    mov r10, [A+eax]
                    add eax, 64
                    cmp eax, SIZE1
                    jl L1

                    mov eax, 0
                L2:
                    mov r10, [A+eax]
                    add eax, 64
                    cmp eax, SIZE2
                    jl L2

                    mov eax, 0
                L3_1:
                    mov r10, [A+eax]
                    add eax, 64
                    cmp eax, SIZE3
                    jl L3_1

                    mov eax, 0
                L3_2:
                    mov r10, [A+eax]
                    add eax, 64
                    cmp eax, SIZE3
                    jl L3_2
                    
                    mov rdi, 0
                    mov	eax, 60	    ; rax = syscall number
                    syscall         ; exit(rdi)";

    print $fh "$code";

    close $fh or die "[generate_code] Can't close '$fname': $!";

    print "Finished generating '$fname'\n";
    return $fname;
}


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
    my $outf = basename($fname);
    $outf =~ s/\.asm$//;
    my $objf = "$tmpdir/" . $outf . ".o";
    $outf = "bin/" . $outf;

    print "Compiling '$fname'\n";
    system("nasm -Wall -felf64 -o $objf $fname") == 0 or die "[compile_code] Compililation failed: $!";
    system("ld -o $outf $objf") == 0 or die "[compile_code] Linking failed: $!";
    print "Finished compiling '$outf'\n";

    return $outf;
}

1;
