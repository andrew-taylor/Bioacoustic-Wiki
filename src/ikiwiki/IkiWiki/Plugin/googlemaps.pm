#!/usr/bin/perl
# Ikiwiki google maps API plugin
# peteg42 at gmail dot com, begun August 2009.
package IkiWiki::Plugin::googlemaps;

use warnings;
use strict;
use IkiWiki 3.00;

use CGI::FormBuilder;
use File::Spec;
use File::stat;
use POSIX;
use XML::LibXML;

my $region_map_filename = 'region_map.kml';

=pod

Supports embedding a map on a wiki page using the [[!googlemaps]]
directive, editing a region map via the CGI script
(?do=edit_region_map&page=...), and placing a flag on the map while
uploading a sound file.

Metadata is stored externally to the page.
FIXME this may interfere with the attachments plugin.
FIXME spell out what metadata.

Limitations:

This plugin only supports Google Maps v2 as v3 was incomplete when it
was started. (Specifically drawing polygons was not supported.)

Only one map per page is supported (for not particularly deep or good
reasons).

FIXME

Show a static map while the JS loads:
http://www.nearby.org.uk/google/static3.php

=cut

# The HTML id of the map <div>.
# FIXME this should be made more dynamic.
my $googlemaps_id = 'map_canvas';

# CGI callback 'do' parameter.
my $region_edit_action = 'region_edit';
my $user_auth_action = 'canedit';
my $user_login_action = 'login_and_go';

sub import {
    add_underlay('javascript');

    IkiWiki::loadplugin('taxonomy');

    hook(type => 'format', id => 'googlemaps', call => \&format);
    hook(type => 'getsetup', id => 'googlemaps', call => \&getsetup);
    hook(type => "needsbuild", id => "googlemaps", call => \&needsbuild);
    hook(type => 'preprocess', id => 'googlemaps', call => \&preprocess);
    hook(type => 'sessioncgi', id => 'googlemaps', call => \&sessioncgi);
}

sub getsetup () {
    return
        plugin => {
            description => 'Render Google Maps on wiki pages.',
            safe => 1,
            rebuild => 0
        },
        googlemaps_key => {
            type => 'string',
            description => 'Google Maps key',
            example => 'ABQIAAAAa2F4nJ-WIrk6lQCWEaykgRQLQrUSm6gLsvF8tRFBRtby5YXseRRBCxRe0PriTnqf8CrGoiVl9ZYF0w',
            safe => 1,
            rebuild => 1
        },
        googlemaps_region_edit_pagespec => {
            type => 'pagespec',
            example => '*/species/*',
            description => 'PageSpec of pages that have editable region maps',
            link => 'ikiwiki/PageSpec',
            safe => 1,
            rebuild => 1,
        },
}

sub needsbuild (@) {
    my ($files) = @_;

    # Process the KML files that are scheduled for re-rendering.
    foreach my $kml_filename (grep { /$region_map_filename$/ } @{$files}) {
        my $page = $kml_filename;
        $page =~ s!/$region_map_filename$!!;

        # warn " >> FIXME Found KML for $page";
        $pagestate{$page}{googlemaps}{polys} = kml_regions_to_js_polys(File::Spec->catdir($config{srcdir}, $kml_filename));

        debug "googlemaps::needsbuild adding dependency: '$page' -> '$kml_filename'";
        add_depends($page, $kml_filename);
    }

    return $files;
}

########################################
# Google polygon futzing routines.
# http://www.usnaviguide.com/google-encode.htm

# Convert a Polygon of Points into a Google Encoded Polygon in Perl Download Zipped
# Google Polygon Encoding algorithm
# Author. John D. Coryat 10/2007 USNaviguide.com and Marcelo Montagna maps.forum.nu
# Adapted from: http://facstaff.unca.edu/mcmcclur/GoogleMaps/EncodePolyline/

# Call as: (<Encoded Levels String>, <Encoded Points String>) = &Google_Encode(<Reference to array of points>, <tolerance in meters>);
# Points Array Format:
# ([lat1,lng1],[lat2,lng2],...[latn,lngn])
#

sub Google_Encode
{
 my $pointsRef	= shift;
 my $tolerance	= shift ;
 my @points	= @{$pointsRef};
 my $encodedPoints = '' ;
 my $encodedLevels = '' ;

 # Check for tolerance size...

 if ( !defined($tolerance) or !$tolerance )
 {
  $tolerance	= 1 ;				# Default Value: 1 meter
 }

 # Run D-P on the points, eliminate redundancies...

 @points = &Douglas_Peucker( \@points, $tolerance ) ;

 # Encode Points...

 $encodedPoints = &createEncodings(\@points);

 # Encode Levels...

 $encodedLevels = &encodeLevels(\@points, $tolerance);

 # Escape backslashes

 $encodedPoints =~ s!\\!\\\\!g;

 return ($encodedLevels, $encodedPoints);
}

sub encodeLevels
{
 my $pointsRef	= shift ;
 my $tolerance	= shift ;
 my @points	= @{$pointsRef};
 my @point	= ( ) ;
 my %pnthash	= ( ) ;
 my @pntlev	= ( ) ;
 my $numLevels	= 18 ;
 my $zoomFactor	= 2 ;
 my $en_levels	= '' ;
 my $lat	= 0 ;
 my $lng	= 0 ;
 my $i		= 0 ;
 my $j		= 0 ;
 my $k		= 0 ;
 my $x		= '' ;
 my $encodelev	= &encodeNumber(1) ;

 # Build up a point hash to be used to reference original points to their location...
 # Mark all points at lowest possible level to start...

 for($i=0; $i < scalar(@points); $i++)
 {
  $pointsRef = $points[$i];
  @point = @{$pointsRef};
  $lat = $point[0];
  $lng = $point[1];
  $pnthash{"$lat,$lng"} = $i ;
  $pntlev[$i] = $encodelev ;
 }

 # Iterate through the levels and calculate with an increasing tolerance...
 # Each time through, mark all points left with current level...

 for($i = 1; $i < $numLevels; $i++)
 {
  @points = &Douglas_Peucker( \@points, $tolerance * ($zoomFactor ** $i) ) ;

  $encodelev	= &encodeNumber($i) ;

  # Mark Points Still present...

  for($j=0; $j < scalar(@points); $j++)
  {
   $pointsRef = $points[$j];
   @point = @{$pointsRef};
   $lat = $point[0];
   $lng = $point[1];
   $k = $pnthash{"$lat,$lng"} ;
   $pntlev[$k] = $encodelev ;
  }

  # Stop when all points are calculated and only 3 are left (line)...

  if ( scalar(@points) < 4 )
  {
   last ;
  }
 }

 # Force first and last point to be highest level...

 $encodelev = &encodeNumber($numLevels - 1) ;

 $pntlev[0] = $encodelev ;
 $pntlev[$#pntlev] = $encodelev ;

 # Build up encoded Level string...

 foreach $x ( @pntlev )
 {
  $en_levels .= $x ;
 }

 return $en_levels;
}

# ############## Numeric subroutines below #############################
# Documentation from Google http://www.google.com/apis/maps/documentation/polylinealgorithm.html
#
#   1. Take the initial signed value:
#	  -179.9832104
#   2. Take the decimal value and multiply it by 1e5, flooring the result:
#	  -17998321

sub createEncodings
{
 my $pointsRef	= shift ;
 my @points 	= @{$pointsRef};
 my $encoded_points = '' ;
 my $pointRef	= '' ;
 my @point	= ( ) ;
 my $plat	= 0 ;
 my $plng	= 0 ;
 my $lat	= 0 ;
 my $lng	= 0 ;
 my $late5	= 0 ;
 my $lnge5	= 0 ;
 my $dlat	= 0 ;
 my $dlng	= 0 ;
 my $i		= 0 ;

 for($i=0; $i < scalar(@points); $i++)
 {

  $pointRef = $points[$i];
  @point = @{$pointRef};
  $lat = $point[0];
  $lng = $point[1];
  $late5 = floor($lat * 1e5);
  $lnge5 = floor($lng * 1e5);
  $dlat = $late5 - $plat;
  $dlng = $lnge5 - $plng;
  $plat = $late5;
  $plng = $lnge5;
  $encoded_points .= &encodeSignedNumber($dlat) . &encodeSignedNumber($dlng);
 }
 return $encoded_points;
}

#   3. Convert the decimal value to binary. Note that a negative value must be inverted 
#      and provide padded values toward the byte boundary:
#	  00000001 00010010 10100001 11110001
#	  11111110 11101101 10100001 00001110
#	  11111110 11101101 01011110 00001111
#   4. Shift the binary value:
#	  11111110 11101101 01011110 00001111 0
#   5. If the original decimal value is negative, invert this encoding:
#	  00000001 00010010 10100001 11110000 1
#   6. Break the binary value out into 5-bit chunks (starting from the right hand side):
#	  00001 00010 01010 10000 11111 00001
#   7. Place the 5-bit chunks into reverse order:
#	  00001 11111 10000 01010 00010 00001
#   8. OR each value with 0x20 if another bit chunk follows:
#	  100001 111111 110000 101010 100010 000001
#   9. Convert each value to decimal:
#	  33 63 48 42 34 1
#  10. Add 63 to each value:
#	  96 126 111 105 97 64
#  11. Convert each value to its ASCII equivalent:
#	  `~oia@

sub encodeSignedNumber
{
 use integer;
 my $num 	= shift;
 my $sgn_num 	= $num << 1;

 if ($num < 0)
 {
  $sgn_num = ~($sgn_num);
 }
 return &encodeNumber($sgn_num);
}

sub encodeNumber
{
 use integer;
 my $encodeString = '' ;
 my $num	= shift;
 my $nextValue	= 0 ;
 my $finalValue	= 0 ;

 while($num >= 0x20)
 {
  $nextValue = (0x20 | ($num & 0x1f)) + 63;
  $encodeString .= chr($nextValue);
  $num >>= 5;
 }
 $finalValue = $num + 63;
 $encodeString .= chr($finalValue);
 return $encodeString;
}

########################################
# Douglas - Peucker algorithm
# Author. John D. Coryat 01/2007 USNaviguide.com
# Adapted from: http://mapserver.gis.umn.edu/community/scripts/thin.pl
##
# Douglas-Peucker polyline simplification algorithm. First draws single line
# from start to end. Then finds largest deviation from this straight line, and if
# greater than tolerance, includes that point, splitting the original line into
# two new lines. Repeats recursively for each new line created.
##

# Call as: @Opoints = &Douglas_Peucker( <reference to input array of points>, <tolerance>) ;
# Returns: Array of points
# Points Array Format:
# ([lat1,lng1],[lat2,lng2],...[latn,lngn])
#

sub Douglas_Peucker
{
my $href	= shift ;
my $tolerance	= shift ;
my @Ipoints	= @$href ;
my @Opoints	= ( ) ;
my @stack	= ( ) ;
my $fIndex	= 0 ;
my $fPoint	= '' ;
my $aIndex	= 0 ;
my $anchor	= '' ;
my $max		= 0 ;
my $maxIndex	= 0 ;
my $point	= '' ;
my $dist	= 0 ;
my $polygon	= 0 ;					# Line Type

$anchor = $Ipoints[0] ; 				# save first point

push( @Opoints, $anchor ) ;

$aIndex = 0 ;						# Anchor Index

# Check for a polygon: At least 4 points and the first point == last point...

if ( $#Ipoints >= 4 and $Ipoints[0] == $Ipoints[$#Ipoints] )
{
 $fIndex = $#Ipoints - 1 ;				# Start from the next to last point
 $polygon = 1 ;						# It's a polygon

} else
{
 $fIndex = $#Ipoints ;					# It's a path (open polygon)
}

push( @stack, $fIndex ) ;

# Douglas - Peucker algorithm...

while(@stack)
{
 $fIndex = $stack[$#stack] ;
 $fPoint = $Ipoints[$fIndex] ;
 $max = $tolerance ;		 			# comparison values
 $maxIndex = 0 ;

 # Process middle points...

 for (($aIndex+1) .. ($fIndex-1))
 {
  $point = $Ipoints[$_] ;
  $dist = perp_distance($anchor, $fPoint, $point);

  if( $dist >= $max )
  {
   $max = $dist ;
   $maxIndex = $_;
  }
 }

 if( $maxIndex > 0 )
 {
  push( @stack, $maxIndex ) ;
 } else
 {
  push( @Opoints, $fPoint ) ;
  $anchor = $Ipoints[(pop @stack)] ;
  $aIndex = $fIndex ;
 }
}

if ( $polygon )						# Check for Polygon
{
 push( @Opoints, $Ipoints[$#Ipoints] ) ;		# Add the last point

 # Check for collapsed polygons, use original data in that case...

 if( $#Opoints < 4 )
 {
  @Opoints = @Ipoints ;
 }
}

return ( @Opoints ) ;

}

# Calculate Perpendicular Distance in meters between a line (two points) and a point...
# my $dist = ⊥_distance( <line point 1>, <line point 2>, <point> ) ;

sub perp_distance					# Perpendicular distance in meters
{
 my $lp1	= shift ;
 my $lp2	= shift ;
 my $p		= shift ;
 my $dist	= &haversine_distance_meters( $lp1, $p ) ;
 my $angle	= &angle3points( $lp1, $lp2, $p ) ; 

 return ( sprintf("%0.6f", abs($dist * sin($angle)) ) ) ;
}

# Calculate Distance in meters between two points...

sub haversine_distance_meters
{
 my $p1	= shift ;
 my $p2	= shift ;

 my $O = 3.141592654/180 ;
 my $b = $$p1[0] * $O ;
 my $c = $$p2[0] * $O ;
 my $d = $b - $c ;
 my $e = ($$p1[1] * $O) - ($$p2[1] * $O) ;
 my $f = 2 * &asin2( sqrt( (sin($d/2) ** 2) + cos($b) * cos($c) * (sin($e/2) ** 2)));

 return sprintf("%0.4f",$f * 6378137) ; 		# Return meters

 sub asin2
 {
  atan2($_[0], sqrt(1 - $_[0] * $_[0])) ;
 }
}

# Calculate Angle in Radians between three points...

sub angle3points					# Angle between three points in radians
{
 my $p1	= shift ;
 my $p2	= shift ;
 my $p3 = shift ;
 my $m1 = &slope( $p2, $p1 ) ;
 my $m2 = &slope( $p3, $p1 ) ;

 return ($m2 - $m1) ;

 sub slope						# Slope in radians
 {
  my $p1	= shift ;
  my $p2	= shift ;
  return( sprintf("%0.6f",atan2( (@$p2[1] - @$p1[1]),( @$p2[0] - @$p1[0] ))) ) ;
 }
}

########################################
# KML encoding.

=pod
    my $polys_arrayref = kml_regions_to_js_polys($kml_filename);
=cut
sub kml_regions_to_js_polys {
    my ($kml_filename) = @_;
    my @polys;

    # FIXME this is a validating parser, catch the exception if it fails
    # ... and do what?
    my $xmlp = XML::LibXML->new();
    my $xmld = $xmlp->parse_file($kml_filename);

    # warn "Loaded KML file $kml_filename: " . $xmld->toString();

    # FIXME hack: works for today's KML files, maybe not tomorrow's.
    # Assume all <coordinate> subtrees define polygons.
    # Note that KML uses long, lat, altitude
    # whereas Google_Encode wants lat, long
    for my $coordinates ($xmld->getElementsByTagName('coordinates')) {
        my @coords;
        my $text = $coordinates->textContent;

        while($text =~ /(.*),(.*),.*/g) {
            # Swap long, lat here.
            push @coords, [$2, $1];
        }

        push @polys, render_js_poly(Google_Encode(\@coords));
    }

    return \@polys;
}

sub render_js_poly {
    my ($levels, $pts) = @_;

    return "{polylines: [{points: '$pts',
                          levels: '$levels',
     color: '#ff0000',
     opacity: 0.3,
     weight: 3,
     numLevels: 18,
     zoomFactor: 2}],
            fill: true,
            color: '#ff0000',
            opacity: 0.1,
            outline: true
        }";
}

########################################
# Region editing.
# This is an AJAX callback, so we don't need to respond with much.

# FIXME straighten out the RCS story here. Needs some help from the JS.
sub sessioncgi {
    my ($q, $session) = @_;

    if($q->param('do') eq $region_edit_action) {
        my $page = $q->param('page');
        my $file = region_map_location($page);

        IkiWiki::check_canedit('FIXME', $q, $session);
#        IkiWiki::checksessionexpiry($q, $session, $field->{sid});

#    $form->field(name => 'sid', type => 'hidden', value => $session->id);
#    $form->field(name => 'page', type => 'hidden', value => $page);

        # $form->field(name => 'rcsinfo', type => 'hidden',
        #              value => IkiWiki::rcs_prepedit($file), force => 1);

        warn "googlemaps save region: " . $page;
        # FIXME there might be a conflict, so this might fail
        # FIXME we don't have rcsinfo...
        commit_region_map( page => $page
                         , kml => $q->param('regions')
                         , rcsinfo => $q->param('rcsinfo')
                         , session => $session
            );

        # The trailing question mark tries to avoid broken
        # caches and get the most recent version of the page.
        IkiWiki::printheader($session);
        print "Updated region info.";
        exit;
    }
}

=pod
    my $region_map_filename = region_map_location($page);

The region maps for each page live in the same place as the
attachments for that page.

$region_map_filename is relative to $config{srcdir}.

=cut
sub region_map_location {
    my ($page) = @_;

    # Put the attachment in a subdir of the page it's attached to,
    # unless that page is an "index" page.
    $page =~ s/(^|\/)index//;

    # FIXME Strip off the '.mdwn' if present.
    $page =~ s/\.mdwn$//;
    $page .= "/" if length $page;

    my $filename = $page
        ? File::Spec->catfile($page, $region_map_filename)
        : $region_map_filename;

    return $filename;
}

sub commit_region_map {
    my %params = @_;

    my $page = $params{page};
    my $kml_filename = region_map_location($page);

    warn "googlemaps commit_region_map: $kml_filename";

    # Validate the KML.
    # FIXME handle exception thrown here.
    my $xmlp = XML::LibXML->new();
    my $xmld = $xmlp->parse_string($params{kml});

    # FIXME perhaps tweak the format of toString
    IkiWiki::writefile($kml_filename, $config{srcdir}, $xmld->toString());

    # Stash the region map into the RCS.
    # FIXME this should be simple as noone gets to futz with our stuff.
    my $conflict;
    my $msg = "Updated region map for '$page'";

    if($config{rcs}) {
        warn "commit_region_map git committing: $kml_filename";

        # Record that the page depends on the KML file.
        IkiWiki::debug("Adding dependency: $page -> $kml_filename");
        add_depends($page, $kml_filename);

        # Scraped from editpage: Prevent deadlock with post-commit
        # hook by signaling to it that it should not try to do
        # anything.
        IkiWiki::disable_commit_hook();
        $conflict = IkiWiki::rcs_commit(
				file => $kml_filename,
				message => $msg,
				token => $params{rcsinfo},
				session => $params{session},
            );
        IkiWiki::enable_commit_hook();

        # FIXME re-render the page. The following apparently works but
        # needs to be verified.

        # FIXME probably don't want to do this.
        IkiWiki::rcs_update();

        # FIXME update the wiki.
        # From editpage.pm: Refresh even if there was a conflict, since
        # other changes may have been committed while the post-commit hook
        # was disabled.
        require IkiWiki::Render;
        IkiWiki::refresh();
        IkiWiki::saveindex();
    }
}

########################################
# The page formatting hooks.

sub preprocess {
    my %params = @_;
    my $page = $params{page};
    my $kml_filename = region_map_location($page);

    my $template = template_depends("googlemaps.tmpl", $page, blind_cache => 1);
    $template->param(googlemaps_id => $googlemaps_id);

    if(pagespec_match($page, $config{googlemaps_region_edit_pagespec},
                      location => $params{page})) {
        $template->param(have_googlemap_actions => 1);
    }

    if($pagestate{$page}{googlemaps}{polys}) {
        my $kml_url = urlto($kml_filename, '', 1);

        # FIXME would be nice...
        #my $timestamp = strftime("%Y%m%dT%H%M%S", stat($kml_filename)->mtime);
        # FIXME eek.
        my $timestamp = stat("$config{srcdir}/$kml_filename")->mtime;

        $template->param(kml_url => $kml_url . '?' . $timestamp);

        if(defined $config{historyurl} && length $config{historyurl}) {
            my $u = $config{historyurl};
            $u =~ s/\[\[file\]\]/$kml_filename/g;
            $template->param(historyurl => $u);
	}
    }

    return $template->output;
}

# Graft the JavaScript loader code onto pages with maps.
sub format (@) {
    my %p = @_;

    if($p{content} =~ m!<div class=".*googlemap.*".*?>!) {
        my $page = $p{page};

        # Add the javascript at the end of the file (best practice).
        if (!($p{content} =~s !(</body>)!include_javascript(page => $page).$1!em)) {
            # no </body> tag, probably in preview mode
            $p{content} .= include_javascript(page => $page);
        }

        # Add an unload event to reduce memory leakage on broken browsers.
        $p{content} =~ s!<body(.*?>)!<body onunload="GUnload()"$1!g;
    }

    return $p{content};
}

sub include_javascript {
    my %p = @_;
    my $page = $p{page};
    my $key = $config{googlemaps_key};
    my $regions;

    $regions = $page
        ? 'var googlemaps_regions=[' . join(',', @{js_polys_for_page($page)}) . '];'
        : '';
    my $initial_marker_pos = $p{initial_marker_pos}
        ? 'var googlemaps_initial_marker_pos=new GLatLng(' . $p{initial_marker_pos}->{latitude}
                                                     . ',' . $p{initial_marker_pos}->{longitude} . ');'
        : '';
    my $edit_callback_params = $page
        ? 'do=' . $region_edit_action . '&amp;page=' . $page
        : '';
    my $auth_callback_params = $page
        ? 'do=' . $user_auth_action . '&amp;page=' . $page
        : '';
    my $login_callback_params = $page
        ? 'do=' . $user_login_action . '&amp;page=' . $page
        : '';

    return '<script src="http://www.google.com/jsapi?key=' . $key .
                 '" type="text/javascript"></script>' ."\n".
           '<script type="text/javascript">google.load("maps", "2.x");</script>'."\n".
           '<script type="text/javascript">'
                  . 'var googlemapsid="' . $googlemaps_id
                  . '"; var googlemaps_cgi_callback="' . $config{cgiurl}
                  . '"; var googlemaps_region_edit_callback_params="' . $edit_callback_params
                  . '"; var googlemaps_auth_callback_params="' . $auth_callback_params
                  . '"; var googlemaps_login_callback_params="' . $login_callback_params
                  . '"; var googlemaps_draw_marker=' . (defined $p{draw_marker} ? '1' : '0')
                  . '; var googlemaps_base_icon_url="' . $config{url} . '/"'
                  . '; ' . $initial_marker_pos
                         . $regions
                  . '</script>'."\n" .
           '<script src="'.urlto('googlemaps.js', '', 1) # FIXME 1 --> absolute URL
                  . '" type="text/javascript"></script>'."\n";
}

=pod
    my $polys = js_polys_for_page($page);
=cut
my %polys_memo;

sub js_polys_for_page {
    my ($page) = @_;

    if(pagespec_match($page, $config{googlemaps_region_edit_pagespec}, location => $page)) {
        return $pagestate{$page}{googlemaps}{polys} || [];
    } elsif($page =~ /taxonomy/) {
        # FIXME Combine all the KML from subpages.
        # FIXME really tied to the taxonomy plugin.
        my $species_fn = sub {
            my %p = @_;
            my $page = IkiWiki::Plugin::taxonomy::species_page($p{genus}, $p{species});

            return $pagestate{$page}{googlemaps}{polys} || [];
        };

        my $node_fn = sub {
            my %p = @_;

            # Perl's interpolation does the concatenation for us.
            return [map { @{$_}; } @{$p{children}}];
        };

        return IkiWiki::Plugin::taxonomy::traverse_taxonomy_tree($page, $species_fn, $node_fn, \%polys_memo);
    } else {
        # FIXME also treat the home page.
        warn "FIXME non-editable map on non-taxonomy page '$page'.";
        return [];
    }
}

1;
