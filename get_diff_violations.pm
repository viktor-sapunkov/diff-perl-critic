# returns a list of Perl::Critic::Violation objects found in the current
# source file and absent in its previous version; additionally some violations
# are returned unconditionally (as being fatal).
# Takes 3 positional parameters (each being a reference to a hash): the
# descriptor of the previous version of a source file, the descriptor of
# the current version of a source file and a severity-to-bool map of
# violations considered as fatal.
# Subjected for changes; no assumptions should be made. Even API is
# unstable.
sub get_diff_violations {
    my ( $prev, $cur, $fatal ) = @_;
    my @violations;

    my $saved_fmt = Perl::Critic::Violation::get_format( );

    Perl::Critic::Violation::set_format( '%L: %p %m %r' );
    my ( %prev_byline, %cur_byline );

    foreach my $v ( @{ $prev->{ violations } } ) {
        my $str = "$v";
        my ( $lineno, $tx ) = ( $str =~ m/^(\d+):\s+(.+?)\s*$/ );
        push @{ $prev_byline{ $lineno } }, { v => $v, tx => $tx };
    }
    foreach my $v ( @{ $cur->{ violations } } ) {
        my $str = "$v";
        my ( $lineno, $tx ) = ( $str =~ m/^(\d+):\s+(.+?)\s*$/ );
        push @{ $cur_byline{ $lineno } }, { v => $v, tx => $tx };
    }

    my %offset_cur2prev =
        get_cur2prev_offset( map { $_->{ file } } ( $prev, $cur ) );

# now that we have %offset_cur2prev populated, find out any new violations as:
# @violations = %cur_byline - %prev_byline. This task has a bit more
# difficulty because values of hashes are lists of hashes (there can be >1
# violation in a line; one can correct one and introduce another at once).

    # sentinel value for brand-new lines (all violations will be included).
    my $sentinel = [ ];
    $prev_byline{ $sentinel } = [ ];    # no 'prev' violations

    foreach my $curline ( sort { $a <=> $b } keys %cur_byline ) {
        my $prev_line = $offset_cur2prev{ $curline } || $sentinel;
        my %prev = map { $_->{tx} => 1 } @{ $prev_byline{ $prev_line } };

        push @violations,
            grep { ! $prev{ $_->{tx} } || $fatal->{ $_->{v}->severity } }
                        @{ $cur_byline{ $curline } };
    }

    Perl::Critic::Violation::set_format( $saved_fmt );
    return map { $_->{v} } @violations;
}

q/At the beginning was the word, but it wasn't a fixed number of bits.../;
