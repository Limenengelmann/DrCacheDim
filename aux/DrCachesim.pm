package DrCachesim;

use strict;
use warnings;

our $drdir="/home/elimtob/.local/opt/DynamoRIO";

sub new_cache {
   my $class = "cache";
   my %args = @_;
   my $self = {
       cfg => { # keys need to be exact DrCachesim config params
           type           => $args{type},
           core           => $args{core},
           size           => $args{size},
           assoc          => $args{assoc},
           inclusive      => $args{inclusive},
           parent         => $args{parent},
           prefetcher     => "none",
           replace_policy => "LRU",
       },
       stats => {
           "Hits"              => undef,
           "Misses"            => undef,
           "Compulsory misses" => undef,
           "Invalidations"     => undef,
           "Miss rate"         => undef,
           "Local miss rate"   => undef,
           "Child hits"        => undef,
           "Total miss rate"   => undef,
       }
   };
   bless $self, $class;
   return $self;
}

sub new_hierarchy {
   my $class = "hierarchy";
   my $self = {
        L1I => new_cache(type => "instruction", core => 0, parent => "L2"),
        L1D => new_cache(type => "data", core => 0, parent => "L2"),
        L2  => new_cache(type => "unified", parent => "L3", inclusive => "false"),
        L3  => new_cache(type => "unified", parent => "memory", inclusive => "false"),
   };
   bless $self, $class;
   return $self;
}

sub parse_results {
    my $cmd = shift;
    my $H   = shift;
    $cmd    =~ s/ -- .*$/ -- echo 'babadibupi'/;

    # safe open to merge stderr and stdout (drcachesim outputs stats to stderr)
    my $pid = open my $cmdout, '-|';
    if ($pid == 0) {
        # child
        open STDERR, ">&", \*STDOUT  or die "Safe open failed: $!";
        exec $cmd or die "Exec failed: $!";
    }
    
    my $state = 0;
    my $c; 
    my $ret;
    while (my $l = <$cmdout>) {
        #print "$l";
        #print "State = $state\n";
        if ($state == 0 && $l =~ /---- <application exited with code (\d+)> ----/) {
            $ret = $1;
            last unless $ret == 0; # on nonzero exit code
            $state = 1;
        } elsif ($state == 1) {
            ($c) = $l =~ /\s*(L1I|L1D|L2|L3) stats:/;
            $state = 2 if $c;
        } elsif ($state == 2) {
            if ($l =~ /\s*(L1I|L1D|L2|L3) stats:/) {
                $c = $1;
                next;
            }
            my ($k, $v) = $l =~ s/(\d),(\d)/$1$2/r =~ /\s+([\w\s]+):\s+([\d.]+)%?/;
            #print "k=$k, v=$v\n";
            die "Regex matching failed\n" if $k eq "" || $v eq "";
            $$H{$c}->{stats}->{$k} = $v;
        }
    }
    return $ret;
}

use File::Temp qw/ tempfile /;
sub create_cfg {
    my $H      = shift;
    my $tmpdir = "/tmp";
    #our $KEEP_ALL = 0;  # delete tmpfile at end of run
    my ($fh, $fname) = tempfile("drcachesim_cfgXXXX", DIR => "/tmp", UNLINK => 1);

    my @C = ();
    my $params = qq#
        num_cores 1
    #;
    push @C, $params;

    foreach my $lvl (keys(%$H)) {
        my $c  = $H->{$lvl}->{cfg};
        my $kv = ();
        foreach my $k (keys(%$c)) {
            my $v = $c->{$k};
            # skip keys that map to references
            next unless defined $v and ref $v eq "";
            push @$kv, "\t$k $v";
        }
        $kv = join "\n", @$kv;
        my $l = qq#
            $lvl {
                $kv
            }
        #;
        push @C, $l;
    }
    my $cfg = join "", @C;
    $cfg =~ s/ {2,}/ /g;    # just for easier human readability

    print $fh "$cfg\n";
    return $fname;
}
