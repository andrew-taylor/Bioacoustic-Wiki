// JavaScript for uploading, soundfiles plugin.
// peteg42 at gmail dot com, begun August 2009.

// ----------------------------------------------------------------------

/**
 * Convert a single file-input element into a 'multiple' input list
 *
 * Usage:
 *
 *   1. Create a file input element (no name)
 *      eg. <input type="file" id="first_file_element">
 *
 *   2. Create a DIV for the output to be written to
 *      eg. <div id="files_list"></div>
 *
 *   3. Instantiate a MultiSelector object, passing in the DIV and an (optional) maximum number of files
 *      eg. var multi_selector = new MultiSelector( document.getElementById( 'files_list' ), 3 );
 *
 *   4. Add the first element
 *      eg. multi_selector.addElement( document.getElementById( 'first_file_element' ) );
 *
 *   5. That's it.
 *
 *   You might (will) want to play around with the addListRow() method to make the output prettier.
 *
 *   You might also want to change the line 
 *       element.name = 'file_' + this.count;
 *   ...to a naming convention that makes more sense to you.
 * 
 * Licence:
 *   Use this however/wherever you like, just don't blame me if it breaks anything.
 *
 * Credit:
 *   If you're nice, you'll leave this bit:
 *  
 *   Class by Stickman -- http://www.the-stickman.com
 *      with thanks to:
 *      [for Safari fixes]
 *         Luis Torrefranca -- http://www.law.pitt.edu
 *         and
 *         Shawn Parker & John Pennypacker -- http://www.fuzzycoconut.com
 *      [for duplicate name bug]
 *         'neal'
 */
function MultiSelector(list_target, max) {
    // Where to write the list
    this.list_target = list_target;
    // How many files to upload?
    this.count = 0;
    // Uniquify the new file input element names.
    // May not be sequential if the user deletes things.
    this.id = 0;

    // Is there a maximum?
    this.max = max ? max : -1;

    /**
     * Add a new file input element. 'element' is the DOM node of some kind of list.
     */
    this.addElement = function(element) {
	// Make sure it's a file input element
	if(element.tagName == 'INPUT' && element.type == 'file') {
	    // Element name -- what number am I?
	    element.name = 'soundfile_' + this.id;
            this.id++;

	    // Add reference to this object
	    element.multi_selector = this;

	    // What to do when a file is selected
	    element.onchange = function() {
		// New file input
		var new_element = document.createElement('input');
		new_element.type = 'file';

		element.parentNode.insertBefore(new_element, element);

		// Apply 'update' to element
		this.multi_selector.addElement(new_element);

		// Update list
		this.multi_selector.addListRow(this);

		// Hide this: we can't use display:none because Safari doesn't like it
                this.style.display = 'none';
		// this.style.position = 'absolute';
		// this.style.left = '-1000px';
	    };

	    // If we've reached maximum number, disable the input element
	    if(this.max != -1 && this.count >= this.max) {
		element.disabled = true;
	    };

	    // File element counter
	    this.count++;

	    // Most recent element
	    this.current_element = element;
	} else {
	    // This can only be applied to file input elements!
	    alert( 'Error: not a file input element' );
	};
    };

    /**
     * Add a new row to the list of files
     */
    this.addListRow = function(element) {
        var new_li = document.createElement('li');
	var new_row = document.createElement('div');
        new_li.appendChild(new_row);

	// Delete button
	var new_row_button = document.createElement( 'input' );
	new_row_button.type = 'button';
	new_row_button.value = 'Delete';
        new_row_button.className ='delete';

	// References
	new_li.element = element;

	// Delete function
	new_row_button.onclick = function() {
	    // Remove element from form
	    // this.parentNode.element.parentNode.removeChild(this.parentNode.element);
	    element.parentNode.removeChild(element);

	    // Remove this row from the list
	    // this.parentNode.parentNode.removeChild( this.parentNode );
	    this.list_target.removeChild(new_li);

	    // Decrement counter
	    // this.parentNode.element.multi_selector.count--;
	    this.multi_selector.count--;

	    // Re-enable input element (if it's disabled)
	    // this.parentNode.element.multi_selector.current_element.disabled = false;
	    this.current_element.disabled = false;

	    // Appease Safari
	    //    without it Safari wants to reload the browser window
	    //    which nixes your already queued uploads
	    return false;
	};

	new_row.innerHTML = element.value;
	new_row.appendChild(new_row_button);
	this.list_target.appendChild(new_li);
    };
};

// ----------------------------------------------------------------------
// Pop-up calendar to select dates.

/*

We need the more sophisticated dialog box variant as we want it to
float near/on the button (and are not prepared to specify absolute
positions of anything).

 */
function initCalendar() {
    var Event = YAHOO.util.Event,
        Dom = YAHOO.util.Dom,
        dialog,
        calendar;

    var showBtn = Dom.get("showCalendar");

    Event.on(showBtn, "click", function() {
            // Lazy Dialog Creation - Wait to create the Dialog, and setup document click listeners, until the first time the button is clicked.
            if (!dialog) {
                // Hide Calendar if we click anywhere in the document other than the calendar
                Event.on(document, "click", function(e) {
                        var el = Event.getTarget(e);
                        var dialogEl = dialog.element;
                        if (el != dialogEl && !Dom.isAncestor(dialogEl, el) && el != showBtn && !Dom.isAncestor(showBtn, el)) {
                            dialog.hide();
                        }
                    });

                dialog = new YAHOO.widget.Dialog("container", {
                    visible:false,
                    context:["showCalendar", "tl", "bl"],
                    buttons:[],
                    draggable:false,
                    close:true
                });
                dialog.setHeader('Pick A Date');
                dialog.setBody('<div id="cal"></div>');
                dialog.render(document.body);

                dialog.showEvent.subscribe(function() {
                    if (YAHOO.env.ua.ie) {
                        // Since we're hiding the table using
                        // yui-overlay-hidden, we want to let the
                        // dialog know that the content size has
                        // changed, when shown
                        dialog.fireEvent("changeContent");
                    }
                });
            }

            // Lazy Calendar Creation - Wait to create the Calendar until the first time the button is clicked.
            if (!calendar) {
                var navConfig = {
                    strings : {
                        month: "Choose Month",
                        year: "Enter Year",
                        submit: "OK",
                        cancel: "Cancel",
                        invalidYear: "Please enter a valid year"
                    },
                    monthFormat: YAHOO.widget.Calendar.SHORT,
                    initialFocus: "year"
                };

                calendar = new YAHOO.widget.Calendar("cal", {
                        navigator: navConfig,
                        iframe:false,          // Turn iframe off, since container has iframe support.
                        hide_blank_weeks:true  // Enable, to demonstrate how we handle changing height, using changeContent
                    });
                calendar.render();

                calendar.selectEvent.subscribe(function() {
                    if (calendar.getSelectedDates().length > 0) {
                        var selDate = calendar.getSelectedDates()[0];

                        function pad0(i) {
                            return i >= 10 ? i : ('0' + i);
                        };

                        var dStr = pad0(selDate.getDate());
                        var mStr = pad0(selDate.getMonth() + 1);
                        var yStr = selDate.getFullYear();

                        Dom.get("date").value = yStr + "/" + mStr + "/" + dStr;
                    } else {
                        Dom.get("date").value = "";
                    }
                    dialog.hide();
                });

                calendar.renderEvent.subscribe(function() {
                    // Tell Dialog it's contents have changed, which
                    // allows container to redraw the underlay (for
                    // IE6/Safari2)
                    dialog.fireEvent("changeContent");
                });
            }

            // Seed the calendar selection with the contents of the text box.
            // .select() is not localised.
            var date_field_val = document.getElementById("date").value;
            var date_matches = date_field_val.match(/^([0-9]{4})\/?(0?[1-9]|1[0-2])\/?(0?[1-9]|[1-2][0-9]|3[0-1])$/);
            if(date_matches) {
                var date = new Date(date_matches[1], date_matches[2] - 1, date_matches[3]);
                calendar.select(date);
            }

            var seldate = calendar.getSelectedDates();

            if (seldate.length > 0) {
                // Set the pagedate to show the selected date if it exists
                calendar.cfg.setProperty("pagedate", seldate[0]);
                calendar.render();
            }

            dialog.show();
        });
};

// ----------------------------------------------------------------------
// Autocompletion of species.

// Also:
// http://developer.yahoo.com/yui/examples/autocomplete/ac_combobox.html
// If species are unknown.

// Data is loaded separately into an array 'species_descriptions'.

function init_species_autocomplete(input_id, output_id, list_container_id, selected_list_id) {
    var matchNames = function(sQuery) {
        // Case insensitive matching
        // sQuery is URL-encoded too (decoding lets us cope with spaces).
        // FIXME might want to search for each elt of a space-separated list of words
        // e.g. sea eagle doesn't match sea-eagle.
        var query = decodeURI(sQuery.toLowerCase());
        var matches = [];

        // Match against all the names of each species.
        // FIXME: perhaps speed this up with a suffix array/etc.
        for(var sci_name in species_descriptions) {
            var species = species_descriptions[sci_name];

            if( (sci_name.toLowerCase().indexOf(query) > -1)
             || (species.description.toLowerCase().indexOf(query) > -1) ) {
                matches[matches.length] = { id: species.id, sci_name: sci_name, description: species.description };
            }
        }

        return matches;
    };

    // Use a FunctionDataSource
    var oDS = new YAHOO.util.FunctionDataSource(matchNames);
    oDS.responseSchema = {
        fields: ["id", "sci_name", "description"]
    }

    // Instantiate AutoComplete
    var oAC = new YAHOO.widget.AutoComplete(input_id, list_container_id, oDS);
    oAC.delimChar = [",",";"]; // Enable comma and semi-colon delimiters
    oAC.maxResultsDisplayed = 50; // FIXME arbitrary
    oAC.resultTypeList = false;
    oAC.useShadow = true;

    // These don't work with substring matching.
//     oAC.autoHighlight = true;
//     oAC.typeAhead = true;

    // Custom formatter to highlight the matching letters
    var formatResult = function(oResultData, sQuery, sResultMatch) {
        var query = sQuery.toLowerCase();
        var sci_name = oResultData.sci_name;
        var description = oResultData.description;
        var query = sQuery.toLowerCase();
        var sci_name_MatchIndex = sci_name.toLowerCase().indexOf(query);
        var description_MatchIndex = description.toLowerCase().indexOf(query);
        var display_sci_name, display_description;

        // FIXME Highlighting just the first match is probably OK
        display_sci_name
          = (sci_name_MatchIndex > - 1)
              ? (display_sci_name = highlightMatch(sci_name, query, sci_name_MatchIndex))
              : sci_name;

        // FIXME probably want to highlight all matches here
        display_description
            = (description_MatchIndex > - 1)
               ? (description_name = highlightMatch(description, query, description_MatchIndex))
               : description;

        return display_description + " <em>" + display_sci_name + "</em>";
    };
    oAC.formatResult = formatResult;

    var highlightMatch = function(full, snippet, matchindex) {
        return full.substring(0, matchindex) +
                "<span class='match'>" +
                full.substr(matchindex, snippet.length) +
                "</span>" +
                full.substring(matchindex + snippet.length);
    };
    if (!selected_list_id) {
    	YAHOO.util.Event.addListener(document.getElementById('_submit'), "click", function(){
    		alert("FIXME");
        });
	    // FIXME show something in the case the list is empty.
	    var ac_sel_event_handler = function(sType, aArgs) {
	        var myAC = aArgs[0]; // reference back to the AC instance
	        var oData = aArgs[2]; // object literal of selected item's result data
	        var d = species_descriptions[oData.sci_name];
	        d = (d ? d.description : '') + " (" + oData.sci_name + ")";
	        myAC.getInputEl().value = d;
	    };
	    oAC.itemSelectEvent.subscribe(ac_sel_event_handler);
    	return;
	}
    // Put selected items into a separate list.
    // The 'id' attribute of the <id>'s is set to the scientific name.
    var ac_sel_ulist = YAHOO.util.Dom.get(selected_list_id);

    var construct_species_row = function(new_li, sci_name) {
		var new_row = document.createElement('div');
	        new_li.appendChild(new_row);
	
	        // Plainly render the match
	        var d = species_descriptions[sci_name];
	        new_row.innerHTML = (d ? d.description : '') + " <em>" + sci_name + "</em>";
	
		// Delete button
		var new_row_button = document.createElement('input');
		new_row_button.type = 'button';
		new_row_button.value = 'Delete';
	        new_row_button.className ='delete';
		new_row.appendChild(new_row_button);
	
		new_row_button.onclick = function() {
	            ac_sel_ulist.removeChild(new_li);
		};
    };

    var construct_species_li = function(sci_name) {
        var li_id = selected_list_id + "_" + sci_name;

        if(document.getElementById(li_id)) {
//             alert("FIXME duplicate: " + li_id);
        } else {
            var new_li = document.createElement('li');
            new_li.id = li_id;
            construct_species_row(new_li, sci_name);
            ac_sel_ulist.appendChild(new_li);
        }
    };

    // FIXME show something in the case the list is empty.
    var ac_sel_event_handler = function(sType, aArgs) {
        var myAC = aArgs[0]; // reference back to the AC instance
        var oData = aArgs[2]; // object literal of selected item's result data

        construct_species_li(oData.sci_name);

        // Erase what the user typed.
        myAC.getInputEl().value = '';
    };
    oAC.itemSelectEvent.subscribe(ac_sel_event_handler);

    // On submission, populate the output widget.
    YAHOO.util.Event.addListener(document.getElementById('_submit'), "click", function(){
            var nodes = ac_sel_ulist.childNodes;
            var output_elt = YAHOO.util.Dom.get(output_id);

            output_elt.value = '';

            for(var n in nodes) {
                var node = nodes[n];

                if(node.nodeName === 'LI') {
                    // Extract the scientific name
                    var sci_name = node.id.substr(selected_list_id.length + 1);

                    output_elt.value = output_elt.value == ''
                        ? sci_name
                        : (output_elt.value + ',' + sci_name);
                }
            }
        });


    // Initialisation
    var nodes = ac_sel_ulist.childNodes;

    for(var n in nodes) {
        var node = nodes[n];

        if(node.nodeName === 'LI') {
            // Extract the scientific name
            var sci_name = node.id.substr(selected_list_id.length + 1);
            construct_species_row(node, sci_name);
        }
    }

    return {
        oDS: oDS,
        oAC: oAC
    };
};

// ----------------------------------------------------------------------
// Initialisation.

YAHOO.util.Event.onDOMReady(function(){
    // The YUI widgets.
    initCalendar();
    init_species_autocomplete('fg_ac_species', 'fg_species', 'fg_autocomplete_container', 'fg_species_autocomplete_selected');
    init_species_autocomplete('bg_ac_species', 'bg_species', 'bg_autocomplete_container', 'bg_species_autocomplete_selected');
    init_species_autocomplete('ac_species', 'species', 'autocomplete_container', '');

    // The multi-file uploader.
    // FIXME hack: if the element isn't there, do nothing.
    var file_elt = document.getElementById('soundfile');
    if(file_elt && typeof file_elt != 'undefined' && file_elt.tagName == 'INPUT' && file_elt.type == 'file') {
        // Create an instance of the multiSelector class, pass it the
        // output target and the max number of files
        var multi_selector = new MultiSelector(document.getElementById('files_list'), 5);
        // Pass in the file element
        multi_selector.addElement(file_elt);

        // We insist that the file list is non-empty when the page is
        // submitted. There's always an extra one, for extending the
        // list. FIXME HACK this is FormBuilder braindamage.
        var s = document.getElementById('_submit');
        var sonclick = s.onclick;
        s.onclick = function() {
            if(multi_selector.count == 1) {
                alert("You must specify at least one file to upload.");
                return false;
            } else {
                return sonclick();
            }
        };
    }
});
