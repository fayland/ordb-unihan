package ORDB::Unihan;

# ABSTRACT: An ORM for the published Unihan database 

use strict;
use warnings;
use Carp ();
use File::Spec 0.80 ();
use File::Path 2.04 ();
use File::Remove 1.42 ();
use File::HomeDir 0.69 ();
use LWP::Online ();
use Params::Util 0.33 qw{ _STRING _NONNEGINT _HASH };
use DBI;
use ORLite 1.22 ();
use vars qw{@ISA};
BEGIN {
	@ISA = 'ORLite';
}


=pod

=head1 SYNOPSIS
 
    TO BE COMPLETED

=head1 DESCRIPTION

TO BE COMPLETED

=head2 METHODS

perldoc L<ORLite>

=cut

my $url = 'http://www.unicode.org/Public/UNIDATA/Unihan.zip';

sub import {
    my $self = shift;
	my $class = ref $self || $self;

    # Check for debug mode
	my $DEBUG = 0;
	if ( scalar @_ and defined _STRING($_[-1]) and $_[-1] eq '-DEBUG' ) {
		$DEBUG = 1;
		pop @_;
	}
	my %params;
	if ( _HASH($_[0]) ) {
		%params = %{ $_[0] };
	} else {
	    %params = @_;
	}

    # where we save .sqlite to?
    # Determine the database directory
	my $dir = File::Spec->catdir(
		File::HomeDir->my_data,
		($^O eq 'MSWin32' ? 'Perl' : '.perl'),
		'ORDB-Unihan',
	);
    # Create it if needed
	unless ( -e $dir ) {
		File::Path::mkpath( $dir, { verbose => 0 } );
	}
	# Determine the mirror database file
	my $db = File::Spec->catfile( $dir, 'Unihan.sqlite' );
	my $zip_path = File::Spec->catfile( $dir, 'Unihan.zip' );

    # Create the default useragent
    my $show_progress = $DEBUG;
	my $useragent = delete $params{useragent};
	unless ( $useragent ) {
		$useragent = LWP::UserAgent->new(
			timeout       => 30,
			show_progress => $show_progress,
		);
	}

    # Do we need refecth?
    my $need_refetch = 1;
    {
        my $last_mod_file = File::Spec->catfile( $dir, 'last_mod.txt' );
        my $last_mod_local = 'N/A';
        if ( open(my $fh, '<', $last_mod_file) ) {
            flock($fh, 1);
            $last_mod_local = <$fh>;
            $last_mod_local ||= 0;
            chomp($last_mod_local);
            close($fh);
        }
        
        my $res = $useragent->head($url);
        my $last_mod = $res->header('last-modified');
        if ( $last_mod_local eq $last_mod ) {
            $need_refetch = 0;
        } else {
            print "Unihan.zip last-modified $last_mod, we have $last_mod_local\n" if $DEBUG;
            open(my $fh, '>', $last_mod_file);
            flock($fh, 2);
            print $fh $last_mod;
            close($fh);
        }
    }

    my $online = LWP::Online::online();
	unless ( $online or -f $db ) {
		# Don't have the file and can't get it
		Carp::croak("Cannot fetch database without an internet connection");
	}

    # refetch the .zip
    my $regenerated_sqlite = 0;
    if ( $need_refetch or ! -e $zip_path ) {
        print "Mirror $url to $zip_path\n" if $DEBUG;
        # Fetch the archive
		my $response = $useragent->mirror( $url => $zip_path );
		unless ( $response->is_success or $response->code == 304 ) {
			Carp::croak("Error: Failed to fetch $url");
		}
		$regenerated_sqlite = 1;
    }
    # Extract .txt file
    if ( $regenerated_sqlite or ! -e File::Spec->catfile( $dir, 'Unihan.txt' ) ) {
        print "Extract $zip_path to $dir\n" if $DEBUG;
        require Archive::Extract;
        my $ae = Archive::Extract->new( archive => $zip_path );
        my $ok = $ae->extract( to => $dir );
        unless ( $ok ) {
            Carp::croak("Error: Failed to read .zip");
        }
        unless ( -e File::Spec->catfile( $dir, 'Unihan.txt' ) ) {
            Carp::croak("Error: Failed to extract .zip");
        }
        
    }
    # regenerate the .sqlite
    if ( $regenerated_sqlite or ! -e $db ) {
        my $dbh = DBI->connect("DBI:SQLite:$db", undef, undef, {
	        RaiseError => 1,
		    PrintError => 1,
	    } );
        
    }
    
	$params{file}     = $db;
	$params{readonly} = 1;
	
	# Hand off to the main ORLite class.
	$class->SUPER::import(
		\%params,
		$DEBUG ? '-DEBUG' : ()
	);

}

1;