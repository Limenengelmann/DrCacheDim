package RefGen;

use strict;
use warnings;
use POSIX qw( ceil );
use File::Temp qw/ tempfile /;
use File::Basename;

use lib "/home/elimtob/Workspace/mymemtrace/aux";
use Aux;
#TODO centralized paths setup

#TODO refactor and name file properly, e.g. depending on which capway macro it actually calls
sub capway_code {
    my $H = shift;

    my $size0 = $H->{L1I}->{cfg}->{size};
    my $ways0 = $H->{L1I}->{cfg}->{assoc};
    my $size1 = $H->{L1D}->{cfg}->{size};
    my $ways1 = $H->{L1D}->{cfg}->{assoc};
    my $size2 = $H->{L2}->{cfg}->{size};
    my $ways2 = $H->{L2}->{cfg}->{assoc};
    my $size3 = $H->{L3}->{cfg}->{size};
    my $ways3 = $H->{L3}->{cfg}->{assoc};

    my $sets0 = $size0 / $ways0 / 64;
    my $sets1 = $size1 / $ways1 / 64;
    my $sets2 = $size2 / $ways2 / 64;
    my $sets3 = $size3 / $ways3 / 64;

    #Round up sizes to powers of two, to avoid unaligning the references
    #TODO needs offset changed for L1I though, so does not work there yet
    #$size0 = 2**int(Aux::log2($size0)+0.5);
    $size1 = 2**ceil(log($size1)/log(2));
    $size2 = 2**ceil(log($size2)/log(2));
    $size3 = 2**ceil(log($size3)/log(2));

    my $gcd0 = Aux::gcd2p($ways0);
    my $gcd1 = Aux::gcd2p($ways1);
    my $gcd2 = Aux::gcd2p($ways2);
    my $gcd3 = Aux::gcd2p($ways3);

    my $fname = "$Aux::TMPDIR/capway-$size0-$ways0-$size1-$ways1-$size2-$ways2-$size3-$ways3.asm";
    print "Generating '$fname'...\n";
    open my $fh, '>', $fname
        or die "[generate_code] Can't open '$fname': $!";

    my $code = qq"
                ; globals
                GLOBAL _start

                ; constants
                LINESIZE equ 64

                SIZE0 equ $size0
                SIZE1 equ $size1
                SIZE2 equ $size2
                SIZE3 equ $size3

                SETS0 equ $sets0
                SETS1 equ $sets1
                SETS2 equ $sets2
                SETS3 equ $sets3

                WAYS0 equ $ways0
                WAYS1 equ $ways1
                WAYS2 equ $ways2
                WAYS3 equ $ways3

                GCD0 equ $gcd0
                GCD1 equ $gcd1
                GCD2 equ $gcd2
                GCD3 equ $gcd3

                OFFS0 equ LINESIZE + (WAYS0-1)*SETS0*LINESIZE
                ; Regression: this 'improvement' allows trading ways for sets 
                ; while keeping performance in some cases
                ;OFFS1 equ LINESIZE*SETS1*GCD1
                ;OFFS2 equ LINESIZE*SETS2*GCD2
                ;OFFS3 equ LINESIZE*SETS3*GCD3
                OFFS1 equ SIZE1
                OFFS2 equ SIZE2
                OFFS3 equ SIZE3

                ; SIZE3*assoc3 so we can access the same tags in a direct mapped cache of the same capacity
                ;GSIZE1 equ SIZE1*GCD1
                ;GSIZE2 equ SIZE2*GCD2
                ;GSIZE3 equ SIZE3*GCD3
                GSIZE1 equ SIZE1*WAYS1
                GSIZE2 equ SIZE2*WAYS2
                GSIZE3 equ SIZE3*WAYS3

                SECTION .bss
                    align LINESIZE
                A:  resb    GSIZE1
                    align LINESIZE
                B:  resb    GSIZE2
                    align LINESIZE
                C:  resb    GSIZE3
                    
                ; TODO: Read in repeats as cmdline params
                ; arguments: 
                ; %1: level 0|1|2|3
                ; %2: #iterations 1|2|3|...
                ; %3: Memory label
                SECTION .text
                _start:
                %macro capway 3
                    mov rdi, 0  ;repeats counter
                    jmp L%1%3
                    align 64
                    %if %1 == 0 ; instruction cache
                        ; L1I aka L0 'run'
                        ;%assign REPS SETS0*WAYS0*WAYS0
                        %assign REPS SETS0*WAYS0*(WAYS0-1)+SETS0
                        ;%assign J0 LINESIZE + (WAYS0-1)*SETS0*LINESIZE
                        %assign i 1
                L0%3:
                        %rep REPS
                            ; LINESIZE bytes of instructions
                            ; $ = current assembly pos, \$ + LINESIZE jump to next block
                            ; end early, since since loop instructions add one cacheline
                            %if i == REPS
                                add rdi, 1
                                cmp rdi, %2
                                jl L%1%3
                            %elif i % SETS0 == 0
                                jmp \$ + OFFS0
                                align LINESIZE    ;fill-up with nop
                            %else
                                jmp \$ + LINESIZE
                                align LINESIZE    ;fill-up with nop
                            %endif
                            %assign i i+1
                        %endrep
                    %else   ; data caches
                L%1%3:
                        lea rax, %3  ;base
                .loop2:
                        mov rsi, 0  ;offset
                .loop1:
                        mov cl, [rax + rsi]

                        add rsi, LINESIZE
                        cmp rsi, LINESIZE*SETS%1
                        jl .loop1

                        ;add rax, SIZE%1
                        add rax, OFFS%1
                        cmp rax, %3 + GSIZE%1
                        jl .loop2

                        ; repeat
                        add rdi, 1
                        cmp rdi, %2
                        jl L%1%3
                    %endif
                %endmacro

                    ; TODO adjust reruns so overall contributions to latency are roughly equal
                    ; TODO flush between adjacent capways
                    capway 0, 2, A
                    capway 1, 2, A
                    capway 2, 2, B
                    capway 3, 2, C

                    ; exit, new cacheline to avoid weird simulator results when instructions cross cachelines
                    jmp EXIT
                    align LINESIZE
                EXIT:
                    mov rdi, 0
                    mov	rax, 60	    ; syscall exit(rdi)
                    syscall
                    nop
                    ";

    print $fh "$code";

    close $fh or die "[generate_code] Can't close '$fname': $!";

    print "Finished generating '$fname'\n";
    return $fname;
}

sub capacity_code {
    my $size1 = shift;
    my $size2 = shift;
    my $size3 = shift;
    my $fname = "$Aux::TMPDIR/optgen-$size1-$size2-$size3.asm";
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

    my $fname = "$Aux::TMPDIR/refgen-$size1-$reps1-$size2-$reps2-$size3-$reps3.asm";
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
    my $objf = "$Aux::TMPDIR/" . $outf . ".o";
    $outf = $Aux::ROOT . "/bin/" . $outf;

    print "Compiling '$fname'\n";
    system("nasm -Wall -felf64 -o $objf $fname") == 0 or die "[compile_code] Compililation failed: $!";
    system("ld -o $outf $objf") == 0 or die "[compile_code] Linking failed: $!";
    print "Finished compiling '$outf'\n";

    return $outf;
}

1;
