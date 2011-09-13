// JavaScript for the googlemaps plugin.
// Based on http://gmaps-samples.googlecode.com/svn/trunk/poly/mymapstoolbar.html
// peteg42 at gmail dot com, begun August 2009.

// The document should define
//   bg_recordings, fg_recordings :: Array recording objects for species pages.
//   user_recordings :: Array for user pages.

// We need to export some stuff. This is our namespace.
// FIXME Should move all the other stuff under it.
var GOOGLEMAPS = {};

// ----------------------------------------------------------------------
// Should be in the Google Maps API.

// Create polygon method for collision detection
// http://dawsdesign.com/drupal/taxonomy/term/15
GPolygon.prototype.containsLatLng = function(latLng) {
    // Do simple calculation so we don't do more CPU-intensive calcs for obvious misses
    var bounds = this.getBounds();

    if(!bounds.containsLatLng(latLng)) {
        return false;
    }

    var numPoints = this.getVertexCount();
    var inPoly = false;
    var i;
    var j = numPoints - 1;

    for(var i=0; i < numPoints; i++) {
        var vertex1 = this.getVertex(i);
        var vertex2 = this.getVertex(j);

        if (vertex1.lng() < latLng.lng() && vertex2.lng() >= latLng.lng() || vertex2.lng() < latLng.lng() && vertex1.lng() >= latLng.lng())  {
            if (vertex1.lat() + (latLng.lng() - vertex1.lng()) / (vertex2.lng() - vertex1.lng()) * (vertex2.lat() - vertex1.lat()) < latLng.lat()) {
                inPoly = !inPoly;
            }
        }

        j = i;
    }

    return inPoly;
};

// ----------------------------------------
// Region editing.

// FIXME namespace polution.
var polyStrokeColour = "#3355ff";
var polyStrokeWeight = 2;
var polyStrokeOpacity = 0.7;
var polyFillColour = "#335599";
var polyFillOpacity = 0.2;

// Convert HTML colours (with or without the '#' prefix) to KML.
// Alpha is in the range 0-1.
// KML: aabbggrr (aa = alpha, in hex)
// HTML/Google Maps: #RRGGBB
// FIXME we expect 6 digits for HTML.
function htmlColourToKML(alpha, html_colour) {
    // Too hard to do with regexps?
    var i;
    var r, g, b;

    i = html_colour.charAt(0) == '#' ? 1 : 0;
    r = html_colour.substr(i, 2);
    g = html_colour.substr(i + 2, 2);
    b = html_colour.substr(i + 4, 2);

    var a = (255 * alpha).toString(16).substr(0, 2);
    if(a.length === 1) {
        a = '0' + a;
    }

    return (a + b + g + r);
};

// Add event handlers when in edit mode.
function activatePoly(map, polys, polyind) {
    var poly = polys[polyind];

    // FIXME how do we remove these events?
    // poly.enableEditing({onEvent: "mouseover"});
    // poly.disableEditing({onEvent: "mouseout"});

    // These can be removed ??
    GEvent.addListener(poly, "mouseover", poly.enableEditing);
    GEvent.addListener(poly, "mouseout", poly.disableEditing);

    // Delete a vertex in a polygon by clicking on it.
    // Delete a polygon by clicking on it (after confirmation).
    GEvent.addListener(poly, "click", function(latlng, index) {
            if (typeof index == 'number') {
                poly.deleteVertex(index);
            } else {
                // Verify that this works.
                if(confirm("Delete this polygon?")) {
                    polys.splice(polyind, 1);
                    map.removeOverlay(poly);
                }
            }
        });
};

function deactivatePoly(poly) {
    // FIXME this is crude: what if something else attaches event
    // handlers to the polygons?
    GEvent.clearInstanceListeners(poly);
};

function startShape(map, polys) {
    return function() {
        var shape_b = document.getElementById("shape_b");

        if(shape_b.className === "selected") {
            // FIXME we might like to abort the shape add here, but
            // for now just ignore subsequent clicks.
        } else {
            shape_b.className = "selected";

            var poly = new GPolygon([], polyStrokeColour, polyStrokeWeight, polyStrokeOpacity, polyFillColour, polyFillOpacity);

            polys.push(poly);
            map.addOverlay(poly);
            activatePoly(map, polys, polys.length - 1);

            // Actually drawing the current shape right now.
            poly.enableDrawing();
            // FIXME probably should treat cancelline() too.
            GEvent.addListener(poly, "endline", function() {
                    shape_b.className = 'unselected';
                });
        }
    }
}

// Encode the polygons into KML.
// FIXME can we build XML some other way?
function serialisePolys(polys) {
    var polygonDepth = "20";

    var result = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
        "<kml xmlns=\"http://www.opengis.net/kml/2.2\">\n" +
        "<Document><name>" + document.title + "</name><description>Range map</description>\n" +
        "<Placemark id=\"range\"><Style>\n<LineStyle><color>"
        + htmlColourToKML(polyStrokeOpacity, polyStrokeColour) + "</color><width>"
        + polyStrokeWeight
        + "</width></LineStyle>\n<PolyStyle><color>"
        + htmlColourToKML(polyFillOpacity, polyFillColour)
        + "</color></PolyStyle>\n</Style><MultiGeometry>\n";

    // FIXME strings, doubtlessly inefficient
    for(var i = 0; i < polys.length; i++) {
        var poly = polys[i];

        result += "<Polygon><extrude>1</extrude>\n<altitudeMode>relativeToGround</altitudeMode>"
            + "<outerBoundaryIs>\n<LinearRing>\n<coordinates>\n";

        for(var j = 0; j < poly.getVertexCount(); j++) {
            var v = poly.getVertex(j);
            result += v.lng() + ',' + v.lat() + ',' + polygonDepth + '\n';
        }

        result += "</coordinates></LinearRing></outerBoundaryIs></Polygon>";
    }

    result += '</MultiGeometry></Placemark>\n</Document>\n</kml>';

    return result;
}

// ----------------------------------------------------------------------
// Region editor, based on Google's My Maps.

// The 'new region' control

// Subclass GControl.
function RegionControl(polys) {
    this.polys = polys;
}
RegionControl.prototype = new GControl();

// Called when the control is added to the map ??
RegionControl.prototype.initialize = function(map) {
    this.map = map;
    var polys = this.polys;

    // Attach events to existing polygons.
    for(var i in polys) {
        activatePoly(map, polys, i);

        // Old polys should change colour when edited.
        (function() {
            var poly = polys[i];
            var lineupdated_event_handler =
                GEvent.addListener(poly, "lineupdated", function() {
                        poly.setStrokeStyle({color: polyStrokeColour, weight: polyStrokeWeight, opacity: polyStrokeOpacity});
                        poly.setFillStyle({color: polyFillColour, opacity: polyFillOpacity});
                        GEvent.removeListener(lineupdated_event_handler);
                    });
        })();
    }

    var container = document.createElement("div");

    var newRegionDiv = document.createElement("div");
    newRegionDiv.id = "shape_b";
    container.appendChild(newRegionDiv);
    GEvent.addDomListener(newRegionDiv, "click", startShape(map, polys));

    // FIXME testing
//     var commitDiv = document.createElement("div");
//     this.setButtonStyle_(commitDiv);
//     container.appendChild(commitDiv);
//     commitDiv.appendChild(document.createTextNode("Save"));
//     GEvent.addDomListener(commitDiv, "click", function(){alert(serialisePolys(polys))});

    map.getContainer().appendChild(container);
    return container;
};

RegionControl.prototype.getDefaultPosition = function() {
  return new GControlPosition(G_ANCHOR_BOTTOM_RIGHT, new GSize(12, 12));
};

RegionControl.prototype.disable = function() {
    var polys = this.polys;

    // Remove events from all polygons.
    for(var i in polys) {
        deactivatePoly(polys[i]);
    }

    this.map.removeControl(this);
}

// FIXME shuffle into local.css?
// Sets the proper CSS for the given button element.
RegionControl.prototype.setButtonStyle_ = function(button) {
  button.style.textDecoration = "underline";
  button.style.color = "#0000cc";
  button.style.backgroundColor = "white";
  button.style.font = "small Arial";
  button.style.border = "1px solid black";
  button.style.padding = "2px";
  button.style.marginBottom = "3px";
  button.style.textAlign = "center";
  button.style.width = "6em";
  button.style.cursor = "pointer";
};

// Top-level for regions and region editing.
function regionsInit(map, latlngbounds) {
    var editing = false;
    var region_control = null;
    var polys = new Array();

    // Draw the initial polygons.
    if(typeof googlemaps_regions != 'undefined') {
        for(var i in googlemaps_regions) {
            var r = googlemaps_regions[i];

            var poly = new GPolygon.fromEncoded(r);
            polys.push(poly);
            map.addOverlay(poly);

            // Take the union of two GLatLngBounds regions. (This is in v3 of the API).
            var polybounds = poly.getBounds();

            latlngbounds.extend(polybounds.getSouthWest());
            latlngbounds.extend(polybounds.getNorthEast());
        }
    }

    // Warn about unsaved changes. Chain the old onbeforeunload handler.
    var onbeforeunload_old;
    var confirm_leave = function(e) {
	if(!e) e = window.event;
	//e.cancelBubble is supported by IE - this will kill the bubbling process.
	e.cancelBubble = true;
	e.returnValue = 'You are currently editing the region map.';

	//e.stopPropagation works in Firefox.
	if(e.stopPropagation) {
	    e.stopPropagation();
	    e.preventDefault();
	} else {
            onbeforeunload_old(e);
        }
    }

    var edit_regions_elt = document.getElementById('googlemap_edit_regions_button');
    if(edit_regions_elt) {
        var req = null;

        GEvent.addDomListener(edit_regions_elt, "click", function() {
                edit_regions_elt.disabled = true;

                if(req === null) {
                    req = new XMLHttpRequest();
                }

                if(!editing) {
                    // Verify that the user can edit the map.
                    edit_regions_elt.innerHTML = 'Authenticating...';

                    req.open('POST', googlemaps_cgi_callback, true);
                    req.onreadystatechange = function(aEvt) {
                        if(req.readyState == 4) {
                            if(req.status == 200) {
                                if(!region_control) {
                                    region_control = new RegionControl(polys);
                                }

                                map.addControl(region_control);
                                edit_regions_elt.innerHTML = 'Save regions';
                                editing = true;

                                // Warn the user if they have unsaved changes.
                                onbeforeunload_old = window.onbeforeunload;
                                window.onbeforeunload = confirm_leave;
                            } else {
                                // alert("FIXME not authenticated: " + req.status + " / " + req.readyState);
                                alert("Not logged in... redirecting to login page.");
                                window.location = googlemaps_cgi_callback + '?' + googlemaps_login_callback_params;
                            }

                            edit_regions_elt.disabled = false;
                        }
                    };
                    req.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                    req.send(googlemaps_auth_callback_params);
                } else {
                    edit_regions_elt.innerHTML = 'Saving regions...';

                    req.open('POST', googlemaps_cgi_callback, true);
                    req.onreadystatechange = function(aEvt) {
                        // FIXME handle response
                        if(req.readyState == 4) {
                            if(req.status != 200) {
                                alert("FIXME problem saving the regions: " + req.status + " / " + req.readyState);
                            }

                            // FIXME clunky
                            edit_regions_elt.innerHTML = 'Edit regions';
                            editing = false;
                            edit_regions_elt.disabled = false;
                        }
                    };
                    req.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                    req.send(googlemaps_region_edit_callback_params
                               + '&regions=' + escape(serialisePolys(polys)));

                    region_control.disable();
                    window.onbeforeunload = onbeforeunload_old;
                }
            });
    }
}

// ----------------------------------------------------------------------

// Draw a single draggable flag on the map. Clicking elsewhere
// teleports the marker to that position. Adds the geocoder event
// handler too. Try to get the geocoding to track the marker, if it is
// moved.
function addSingleMarker(map, latlngbounds) {
    var marker;
    var geocoded = true;

    var geocode_latitude = document.getElementById("geocode_latitude");
    var geocode_longitude = document.getElementById("geocode_longitude");
    var geocode_location = document.getElementById('geocode_location');

    var form_latitude = document.getElementById("latitude");
    var form_longitude = document.getElementById("longitude");
    var form_location = document.getElementById('location');

    var updateMetaData = function(point, location) {
        // This is what the user sees.
        geocode_latitude.innerHTML = point.lat();
        geocode_longitude.innerHTML = point.lng();

        if(location) {
            geocode_location.value = location;
        } else if(geocoded) {
            geocoder.getLocations(point, function(r) {
                    if (r && r.Status.code === 200) {
                        var place = r.Placemark[0];
                        geocode_location.value = place.address;
                    }
                });
        }
    };

    function setMarker(point, location) {
        if(point) {
            if(marker) {
                marker.setPoint(point);
            } else {
                marker = new GMarker(point, {draggable:true, bouncy:false, dragCrossMove:true});
                GEvent.addListener(marker, 'dragend', updateMetaData);
                map.addOverlay(marker);
            }
            updateMetaData(point, location);
        }
    };

    // Maps distinguishes clicking on the map and clicking on an overlay.
    // It's all the same to us here.
    GEvent.addListener(map, "click", function(overlay, point, overlayPoint) {
            setMarker(point || overlayPoint);
        });

    var geocoder = new GClientGeocoder();
    // Unnecessary, should be divined from the page URL.
    // geocoder.setBaseCountryCode('au');

    GEvent.addDomListener(document.getElementById('geocode_form'), 'submit', function(e) {
            var address = geocode_location.value;
            geocoder.getLocations(address, function(r) {
                    if (!r || r.Status.code != 200) {
                        alert("\"" + address + "\" not found");
                    } else {
                        var place = r.Placemark[0];
                        var point = new GLatLng(place.Point.coordinates[1],
                                                place.Point.coordinates[0]);

                        geocode_location.value = place.address;
                        map.setCenter(point, 13);
                        setMarker(point);
                        marker.openInfoWindowHtml(place.address);
                        // Start tracking the moving marker.
                        geocoded = true;
                    }
                });
            // Don't actually submit the form.
            e.preventDefault();
        });

    // Stop tracking the moving marker if the user changes the location.
    GEvent.addDomListener(geocode_location, 'keyup', function(e) {
            geocoded = geocode_location.value === '';
        });

    // On submit, stash the geocode info into the form's geocode fields.
    GEvent.addDomListener(document.getElementById('_submit'), 'click', function(){
        if(typeof marker != 'undefined') {
            var latlng = marker.getLatLng();
            form_location.value = geocode_location.value;
            form_latitude.value = latlng.lat();
            form_longitude.value = latlng.lng();
        }
    });

    // Fish the initial values out of the form.
    if(form_latitude.value && form_longitude.value) {
        var latlng = new GLatLng(form_latitude.value, form_longitude.value);
        setMarker(latlng, form_location.value);
        latlngbounds.extend(latlng);
    }
};

// ----------------------------------------------------------------------
// Recording table and markers

// Revert all hilit markers.
function markersUnHilight(hilit_markers, unsel_icon) {
    while(hilit_markers.length > 0) {
        var m = hilit_markers.shift();
        m.setImage(unsel_icon.image);
    }
};

// Hilight a particular marker.
function markerHilight(map, hilit_markers, m, sel_icon) {
    if(m) {
        map.panTo(m.getLatLng());
        m.setImage(sel_icon.image);
        hilit_markers.push(m);
    }
};

// Top-level: draw the markers and set up the event handlers.
function drawRecordings(map, latlngbounds) {
    // FIXME only need the image for the hilight icon, not a GIcon.
    var sel_icon = new GIcon(G_DEFAULT_ICON);
    sel_icon.image = googlemaps_base_icon_url + '/wikiicons/birds_fg.png';
    sel_icon.iconSize = new GSize(32, 37);

    var unsel_icon = new GIcon(G_DEFAULT_ICON);
    unsel_icon.image = googlemaps_base_icon_url + '/wikiicons/birds_bg.png';
    unsel_icon.iconSize = new GSize(32, 37);

    // Temporary array of all recordings with lat/lngs.
    var recordings = new Array();

    // The set of hilit markers.
    var hilit_markers = new Array();

    var f = function(r) {
        // Recordings need not have location info.
        if(r.latitude && r.longitude) {
            // FIXME if there is already a marker at or near this lat/long...
            // This is approximate and inefficient.
            var latlng = new GLatLng(r.latitude, r.longitude);
            var m = null;
            var rs = null;

            for(var j in recordings) {
                // The distance is in metres.
                // Depends on the resolution of the map...
                if(recordings[j].marker.getLatLng().distanceFrom(latlng) < 50) {
                    m = recordings[j].marker;
                    rs = recordings[j].same_loc_recordings;
                    break;
                }
            }

            if(m === null) {
                m = new GMarker(latlng, {title: r.num, icon: unsel_icon});
                map.addOverlay(m);

                // Maintain mappings in both directions between the
                // markers and the recordings (one marker to many
                // recordings).
                r.marker = m;
                r.same_loc_recordings = new Array();

                // Handle clicks on the marker and the table row.
                GEvent.addListener(m, "click", function() {
                        markersUnHilight(hilit_markers, unsel_icon);
                        markerHilight(map, hilit_markers, r.marker, sel_icon);

                        // Delegate the table fiddling to the soundfiles javascript.
                        if(typeof SOUNDFILES.hilight != 'undefined') {
                            SOUNDFILES.hilight(r.same_loc_recordings);
                        }
                    });
            } else {
                r.marker = m;
                r.same_loc_recordings = rs;
            }

            r.same_loc_recordings.push(r);
            latlngbounds.extend(latlng);

            recordings.push(r);
        }
    };

    // FIXME this probably belongs in soundfiles.js
    if(typeof bg_recordings != 'undefined') {
        for(var i in bg_recordings) {
            f(bg_recordings[i]);
        }
    }

    if(typeof fg_recordings != 'undefined') {
        for(var i in fg_recordings) {
            f(fg_recordings[i]);
        }
    }

    if(typeof user_recordings != 'undefined') {
        for(var i in user_recordings) {
            f(user_recordings[i]);
        }
    }

    // Create a function that SOUNDFILES can call to highlight a marker.
    GOOGLEMAPS.hilight = function(r) {
        markersUnHilight(hilit_markers, unsel_icon);
        markerHilight(map, hilit_markers, r.marker, sel_icon);
    };
}

// ----------------------------------------------------------------------
// Main

// Delaying until the DOM is ready seems to save us from worrying
// about whether variables have been defined "further up the page".

google.setOnLoadCallback(function() {
    if(GBrowserIsCompatible()) {
        var map = new GMap2(document.getElementById(googlemapsid));
        var latlngbounds = new GLatLngBounds();

        // By default, show all of Australia. The Google Maps API requires
        // us to call setCenter() before we do anything else with 'map'.
        map.setCenter(new GLatLng(-26.037042, 130.957031), 3, G_PHYSICAL_MAP);
        map.setUIToDefault();

        drawRecordings(map, latlngbounds);

        // Handle the region polygons. Extends latlngbounds with the
        // regions, if any.

        regionsInit(map, latlngbounds);

        // Mode: A click on the map places a marker for a sound
        // recording. Enables geocoding too.
        if(typeof googlemaps_draw_marker != 'undefined' && googlemaps_draw_marker) {
            addSingleMarker(map, latlngbounds);
        }

        // Zoom to all the features on the map.
        // FIXME want a miminum level of zoom: if there's only a few
        // closely-placed flags, things are not good.
        if(! latlngbounds.isEmpty()) {
            map.setCenter(latlngbounds.getCenter(), map.getBoundsZoomLevel(latlngbounds));
        }
    }
});
