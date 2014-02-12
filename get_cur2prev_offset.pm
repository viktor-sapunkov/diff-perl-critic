

# offset to line no. (from the current file to the previous one).
# this is tricky a bit, based on
# http://www.gnu.org/software/diffutils/manual/html_node/Detailed-Normal.html
# Takes 2 positional parameters: paths to the previous and the current source file path.
sub get_cur2prev_offset {
    my ( $prev, $cur ) = @_;

    my %cur2prev;
    my ( $ncur, $nprev ) = ( 0, 0 );    # insertion position (hence 0-based)

    my $diffspec_range =
        sub {
            my $range = shift;
            my ( $pos, $count, @rest ) = split /,/, $range;
            die "BUG: bad range '$range' - redundant commas" if @rest;
            $count ||= $pos;
            $count -= $pos - 1;
            return ( $pos, $count );
        };

    my $a =
        sub {
            my ( $pos1, $count1, $pos2, $count2, ) = @_;
            $nprev++, $ncur++;

            $cur2prev{ $ncur++ } = $nprev++ while ( $ncur < $pos2 );

            # after $nprev line# $rpr, $num lines added into original file
            $cur2prev{ $ncur++ } = undef for ( 1 .. $count2 );

            $nprev--;
            $ncur = $pos2 + $count2 - 1;
            return;
        };
    my $d =
        sub {
            my ( $pos1, $count1, $pos2, $count2, ) = @_;
            $nprev++, $ncur++;

            # $rpr-identified lines deleted from 'prev';
            # new $ncur shall be $rcu
            $cur2prev{ $ncur++ } = $nprev++ while ( $nprev < $pos1 );

            $ncur = $rcu;
            $nprev += $count1 - 1;
            return;
        };
    my $c =
        sub {
            my ( $pos1, $count1, $pos2, $count2, ) = @_;
            $d->( $pos1, $count1, $pos2, $count2, );
            $ncur--;
            $a->( $pos1, $count1, $pos2, $count2, );
        };

    my @diff = map { s/^\s+//; s/\s+$//; $_; } `diff $prev $cur`;
    my @diff_spec = grep { m/^\s*\d+(?:,\d+)?[acd]\d+(?:,\d+)?\s*$/ } @diff;

    foreach ( @diff_spec ) {
        my ( $rpr, $op, $rcu ) = /^(\d+(?:,\d+)?)([acd])(\d+(?:,\d+)?)$/;
        my ( $pos1, $count1 ) = $diffspec_range->( $rpr );
        my ( $pos2, $count2 ) = $diffspec_range->( $rcu );

        if ( $op eq 'a' ) {
            $a->( $pos1, $count1, $pos2, $count2, );
        }
        elsif ( $op eq 'd' ) {
            $d->( $pos1, $count1, $pos2, $count2, );
        }
        elsif ( $op eq 'c' ) {
            $c->( $pos1, $count1, $pos2, $count2, );
        }
        else { die "Unknown diff op='$op'" }
    }

    # fill in the gaps
    my $cur_lines_num = 0;  # cookbook (wc -l)
    open my $fh, '<', $cur;
    binmode( $fh, ':raw' );
    $cur_lines_num += tr/\n/\n/ while sysread( $fh, $_, 2**16 );
    close $fh;

    while ( $ncur <= $cur_lines_num ) {
        my $cur_idx  = $ncur++;
        my $prev_idx = $nprev++;
        next if exists $cur2prev{ $cur_idx };
        $cur2prev{ $cur_idx } = $prev_idx;
    }

    return %cur2prev;
}

q/At the beginning was the word, but it wasn't a fixed number of bits.../;
