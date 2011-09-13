// JavaScript for soundfile metadata, soundfiles plugin.
// peteg42 at gmail dot com, begun August 2009.
// Based on the YUI sample code.

// FIXME could generate the field info at the same time as generating
// the data. Hardwired for now. Maintenance nightmare as it is.

// FIXME date formats

// ----------------------------------------------------------------------
// Nested datatables.
// FIXME hacked: specialised to the "show the rest of the row" case. Nasty!

/*
 Copyright (c) 2010, Daniel Barreiro Lage (aka Satyam)
 Code licensed under the BSD License:
 http://developer.yahoo.net/yui/license.txt
 version: 1.0 (YUI 2.8.0)
 */
/**
 * The NestedDataTable widget provides an extension to YAHOO.widget.DataTable 
 * that allows displaying nested DataTables nested within each row of the master table
 *
 * @module nesteddatatable
 * @requires yahoo, dom, event, element, datasource, datatable
 * @title NestedDataTable Widget
 */
/**
 * NestedDataTable class for Satyam's NestedDataTable widget.
 *
 * @namespace YAHOO.widget
 * @class NestedDataTable
 * @extends YAHOO.widget.DataTable
 * @constructor
 * @param elContainer {HTMLElement} Container element for the TABLE.
 * @param masterColDefs {Object[]} Array of object literal Column definitions for the master table.
 * @param masterDataSource {YAHOO.util.DataSource} DataSource instance for the master table.
 * @param nestedColDefs {Object[]} Array of object literal Column definitions for the nested tables.
 * @param nestedDataSource {YAHOO.util.DataSource} DataSource instance for the nested tables.
 * @param masterOptions {object} (optional) Object literal of configuration values for the master table.
 * @param nestedOptions {object} (optional) Object literal of configuration values for the nested tables.
 */

(function () {
    var Dom = YAHOO.util.Dom,
        Event = YAHOO.util.Event,
        Lang = YAHOO.lang,
        DT = YAHOO.widget.DataTable,
        NESTED = '__NESTED__',
        NESTED_TABLE = '__NESTED_TABLE__';


    var NDT = function (elContainer, masterColDefs, masterDataSource, nestedColDefs, nestedFieldDefs, masterOptions, nestedOptions) {
        this._nestedColDefs = nestedColDefs;
        this._nestedFieldDefs = nestedFieldDefs;
        this._nestedOptions = nestedOptions || {};

        // Add the column with the toggle button
        masterColDefs.unshift({
            key: NESTED,
            label: ' ',
            className: NESTED,
            formatter: this._toggleFormatter
        });

        NDT.superclass.constructor.call(this, elContainer, masterColDefs, masterDataSource, masterOptions);

        // Listen for a click on the toggle column
        this.on('cellClickEvent', this._onEventToggleNested);

        // Whenever the master table is re-rendered, for example, in a sort, 
        // we need to adjust the position of the child tables
        this.on('renderEvent', this._onMasterRendered);
        // on a window resize the master table may move around, 
        // we need to adjust the nested tables
        Event.on(window, 'resize', this._onWindowResized, this, true);

        // when rows are deleted, we need to delete the nested tables
        this.on('rowDeleteEvent', this._onRowDeleteDestroyNested);
        this.on('rowsDeleteEvent', this._onRowsDeleteDestroyNested);
    };

    YAHOO.widget.NestedDataTable = NDT;

    Lang.extend(NDT, DT, {
        // adding the generateNestedRequest configuration attribute
        initAttributes: function (oConfigs) {
            NDT.superclass.initAttributes.apply(this, arguments);
        },
        /**
         * Loops through all the records and calls the given function on all those
         * that have nested tables.
         * The function will receive:
         * <ul>
         * <li><code>detail</code>: details of the nested table (same as provided for all events)</li>
         * <li><code>record</code>: reference to the Record object in the master table</li>
         * </ul>
         *
         * @method _forAllNested
         * @param fn {function} The function to be called on each nested tableelement to format with markup.
         * @private
         */
        _forAllNested: function (fn) {
            var rs = this.getRecordSet(),
                rsl = rs.getLength(),
                record, detail;

            for (var i = 0; i < rsl; i++) {
                record = rs.getRecord(i);
                // With server-side paging and sorting, not all records might be present at once
                // Since you can skip pages, some intermediate records might be missing, 
                // we need to check they exist
                if (record) {
                    detail = record.getData(NESTED);
                    // I only care for records that have a NESTED field, 
                    // that means the record has a child table
                    if (detail) {
                        fn.call(this, detail, record);
                    }
                }
            }
        },

        /**
         * Checks the vertical positions of all the expanded nested tables
         * whenever the master table has been re-arranged
         *
         * @method _checkPositions
         * @private
         */
        _checkPositions: function () {
            this._forAllNested(function (detail, record) {
                if (detail.expanded) {
                    // Move it down from the top corner for as much as the original height of that row
                    Dom.setY(detail.div, Dom.getY(detail.td) + detail.tdOrigHeight);
                    this.fireEvent('nestedMovedEvent', detail);
                }
            });
        },
        /**
         * Formats the toggle cell.  
         * It is a standard cell formatter but is not made public since it is tied to the toggle column
         * and is useless in any other context
         *
         * @method _toggleFormatter
         * @param el {HTMLElement} The element to format with markup.
         * @param oRecord {YAHOO.widget.Record} Record instance.
         * @param oColumn {YAHOO.widget.Column} Column instance.
         * @param oData {Object} (Optional) Data value for the cell.
         * @private
         */
        _toggleFormatter: function (el, oRecord, oColumn, oData) {
            var expanded = oData && oData.expanded;
            if (expanded) {
                Dom.replaceClass(el, 'expand', 'collapse');
            } else {
                Dom.replaceClass(el, 'collapse', 'expand');
            }
            el.innerHTML = '<a href="#" aria-role="button" aria-pressed="' + (expanded ? 'true' : 'false') + '"> &nbsp; </a>';
        },
        /**
         * Expands or collapses the nested table.  
         * It is preset as the event listener for the cellClickEvent
         * and responds only on the toggle column
         *
         * @method _onEventToggleNested
         * @param oArgs.event {HTMLEvent} Event object.
         * @param oArgs.target {HTMLElement} Target element.
         * @private
         */
        _onEventToggleNested: function (oArgs) {
            var target = oArgs.target,
                event = oArgs.event,
                record = this.getRecord(target),
                column = this.getColumn(target);

            if (column.key == NESTED) {
                Event.stopEvent(event);
                var td = this.getFirstTdEl(record),
                    detail = record.getData(NESTED);
                if (!detail) {
                    // if there are no details, we make a new nested table 
                    // and create the field to store the information about it
                    record.setData(NESTED, {
                        td: td,
                        expanded: true
                    });
                    this._makeNestedTable(record);
                } else {
                    // if the nested table exists, we only need to toggle its visibility
                    // and make or take the space for it
                    if (detail.expanded) {
                        detail.expanded = false;
                        Dom.setStyle(td, 'height', null);
                        Dom.setStyle(detail.div, 'display', 'none');
                    } else {
                        detail.expanded = true;
                        Dom.setStyle(td, 'height', detail.tdNewHeight + 'px');
                        Dom.setStyle(detail.div, 'display', '');
                        // if the screen was resized while the table was hidden
                        // we need to position it once made visible since positioning values
                        // are ignored when invisible
                        if (detail.setHorizPos) {
                            Dom.setX(detail.div, Dom.getX(td) + Dom.getRegion(td).width);
                            detail.setHorizPos = false;
                        }
                    }

                    this.fireEvent('nestedToggleEvent', detail);

                    // whether we are collapsing or expanding the detail table
                    // we need to adjust the position of all the tables since they won't
                    // move along their master records
                    this._checkPositions();
                }
                // we have to redraw the toggle icon
                this.formatCell(this.getTdLinerEl(target), record, column);
                return false;
            }
        },

        /**
         * Event listener for the renderEvent on the master table.
         * When the master is rendered, the nested tables have to be repositioned
         * @method _onMasterRendered
         * @private
         */
        _onMasterRendered: function () {
            this._forAllNested(function (detail, record) {
                // The rows of the master table will be redrawn so we need to
                // get a reference to the new toggle cell
                detail.td = this.getFirstTdEl(record);
                // The row might be paged out of view so we must check it is still there
                if (detail.td) {
                    if (detail.expanded) {
                        // the newly rendered cells will all be collapsed
                        // we need to make space for the nested tables
                        Dom.setStyle(detail.td, 'height', detail.tdNewHeight + 'px');
                    }
                } else {
                    // If the row is no longer visible we hide the nested table and mark it as not expanded
                    detail.expanded = false;
                    Dom.setStyle(detail.div, 'display', 'none');
                }

            });
            // now we set the positions
            this._checkPositions();
        },

        /**
         * Event listener for the <code>window.resize</code> event.
         * Repositions the nested tables since the master table might have been moved around
         * @method _onWindowResized
         * @param ev {DOMEvent} the Event object from the DOM
         * @private
         */
        _onWindowResized: function (ev) {
            this._forAllNested(function (detail, record) {
                var td = detail.td;
                // When the detail is expanded, we can adjust the position immediately
                // if not, we need to mark it pending since invisible elements cannot be positioned
                if (detail.expanded) {
                    Dom.setX(detail.div, Dom.getX(td) + Dom.getRegion(td).width);
                } else {
                    detail.setHorizPos = true;
                }
            });
            this._checkPositions();
        },

        /**
         * Makes each of the nested tables
         * @method _makeNestedTable
         * @param record {YAHOO.widget.Record} the Record instance of the master table
         * @private
         */

        _makeNestedTable: function (record) {
            var detail = record.getData(NESTED),
                parent = this;

            // Magic a new data source, just for this row.
            // FIXME stash this somewhere.
            var ds = new YAHOO.util.DataSource([ record.getData() ]);
            ds.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
            ds.responseSchema = { fields: this._nestedFieldDefs };

            // Create the container for the child DataTable that will float
            var div = document.body.appendChild(document.createElement('div'));
            Dom.addClass(div, NESTED_TABLE);

            // the nested datatables are regular instances of DataTable
            var dt = new DT(div, this._nestedColDefs, ds, this._nestedOptions);

            // Since we need to measure the size of the child table to make it space under the master one
            // we have to wait until the table is initialized to find out how tall and wide it is
            dt.on('initEvent', function () {
                var td = detail.td;

                var tdRegion = Dom.getRegion(td),
                    tdHeight = tdRegion.height,
                    tdWidth = tdRegion.width,
                    tableWidth = Dom.getRegion(td.parentNode).width; // that should be the row
                // We keep the original height of the row so we can collapse it to its original size
                detail.tdOrigHeight = tdHeight;
                // We need first to set the width and then to measure the height of the table
                // because if a long title gets in a narrow cell, it will get wrapped to the next
                // line and make the table taller
                Dom.setStyle(div, 'width', (tableWidth - tdWidth + 2) + 'px');
                detail.tdNewHeight = tdHeight + Dom.getRegion(div).height;
                    Dom.setStyle(td, 'height', detail.tdNewHeight + 'px');
                // I offset the child table to the right of the expand icon
                Dom.setX(div, Dom.getX(td) + tdWidth);
                parent._checkPositions();
            });
            // We store both the container and the reference to this child table in the record
            detail.div = div;
            detail.dt = dt;
            this.fireEvent('nestedCreateEvent', detail);
        },

        /**
         * Destroys a nested table
         * @method _destroyNested
         * @param detail.div {HTMLElement} The DIV element containing the nested table instance.
         * @param detail.dt {YAHOO.widget.DataTable} The nested DataTable instance.
         * @param detail.expanded {Boolean} Whether the master record is expanded and the nested table visible
         * @param detail.td {HTMLElement} The toggle cell in the row of the master table
         * @param detail.tdNewHeight {Integer} The height, in pixels, needed for the row in the master record to hold the nested DataTable.
         * @param detail.tdOldHeight {Integer} The original height, in pixels, of the row in the master record before it was expanded.
         * @private
         */
        _destroyNested: function (detail) {
            if (detail) {
                this.fireEvent('nestedDestroyEvent', detail);
                detail.dt.destroy();
                detail.div.parentNode.removeChild(detail.div);
            }
        },
        /**
         * This is an override for DataTable's own <code>initializeTable</code>
         * which it calls after it destroys all nested tables.		 
         *
         * @method initializeTable
         */
        initializeTable: function () {
            this._forAllNested(this._destroyNested);

            NDT.superclass.initializeTable.apply(this, arguments);
        },
        /**
         * This is an override for DataTable's own <code>onDataReturnSetRows</code>
         * which it calls after it destroys all nested tables since
         * with server-side pagination, with every new page it ignores the previous records
         *
         * @method onDataReturnSetRows
         */
        onDataReturnSetRows: function () {
            this._forAllNested(this._destroyNested);
            NDT.superclass.onDataReturnSetRows.apply(this, arguments);
        },

        /**
         * Event listener for the <code>rowDeleteEvent</code> event.
         * Destroys the nested table, if any.
         * @method _onRowDeleteDestroyNested
         * @param oArgs.oldData {Object} Object literal of the deleted data.
         * @param oArgs.recordIndex {Number} Index of the deleted Record.
         * @param oArgs.trElIndex {Number} Index of the deleted TR element, if on current page.
         * @private
         */

        _onRowDeleteDestroyNested: function (oArgs) {
            this._destroyNested(oArgs.oldData[NESTED]);
        },
        /**
         * Event listener for the <code>rowsDeleteEvent</code> event.
         * Destroys the nested tables, if any.
         *
         * @method _onRowsDeleteDestroyNested
         * @param oArgs.oldData {Object[]} Array of object literals of the deleted data.
         * @param oArgs.recordIndex {Number} Index of the first deleted Record.
         * @param oArgs.count {Number} Number of deleted Records.
         * @private
         */
        _onRowsDeleteDestroyNested: function (oArgs) {
            for (var i = 0; i < oArgs.oldData.length; i++) {
                this._destroyNested(oArgs.oldData[i][NESTED]);
            }
        }

    });
})();

/**
 * Fired when a nested table has been moved.
 *
 * @event nestedMovedEvent
 * @param oArgs.div {HTMLElement} The DIV element containing the nested table instance.
 * @param oArgs.dt {YAHOO.widget.DataTable} The nested DataTable instance.
 * @param oArgs.expanded {Boolean} Whether the master record is expanded and the nested table visible
 * @param oArgs.td {HTMLElement} The toggle cell in the row of the master table
 * @param oArgs.tdNewHeight {Integer} The height, in pixels, needed for the row in the master record to hold the nested DataTable.
 * @param oArgs.tdOldHeight {Integer} The original height, in pixels, of the row in the master record before it was expanded.
 */
/**
 * Fired when the row in the master table has been expanded or collapsed.
 *
 * @event nestedToggleEvent
 * @param oArgs.div {HTMLElement} The DIV element containing the nested table instance.
 * @param oArgs.dt {YAHOO.widget.DataTable} The nested DataTable instance.
 * @param oArgs.expanded {Boolean} Whether the master record is expanded and the nested table visible
 * @param oArgs.td {HTMLElement} The toggle cell in the row of the master table
 * @param oArgs.tdNewHeight {Integer} The height, in pixels, needed for the row in the master record to hold the nested DataTable.
 * @param oArgs.tdOldHeight {Integer} The original height, in pixels, of the row in the master record before it was expanded.
 */
/**
 * Fired when a nested table has been created.
 *
 * @event nestedCreateEvent
 * @param oArgs.div {HTMLElement} The DIV element containing the nested table instance.
 * @param oArgs.dt {YAHOO.widget.DataTable} The nested DataTable instance.
 * @param oArgs.expanded {Boolean} Whether the master record is expanded and the nested table visible
 * @param oArgs.td {HTMLElement} The toggle cell in the row of the master table
 * @param oArgs.tdNewHeight {Integer} The height, in pixels, needed for the row in the master record to hold the nested DataTable.
 * @param oArgs.tdOldHeight {Integer} The original height, in pixels, of the row in the master record before it was expanded.
 */
/**
 * Fired when a nested table is about to be destroyed.
 *
 * @event nestedDestroyEvent
 * @param oArgs.div {HTMLElement} The DIV element containing the nested table instance.
 * @param oArgs.dt {YAHOO.widget.DataTable} The nested DataTable instance.
 * @param oArgs.expanded {Boolean} Whether the master record is expanded and the nested table visible
 * @param oArgs.td {HTMLElement} The toggle cell in the row of the master table
 * @param oArgs.tdNewHeight {Integer} The height, in pixels, needed for the row in the master record to hold the nested DataTable.
 * @param oArgs.tdOldHeight {Integer} The original height, in pixels, of the row in the master record before it was expanded.
 */

// ----------------------------------------------------------------------

// The Google maps JS talks to us through this global variable.
var SOUNDFILES = {};

// More haste, less correctness ?
YAHOO.util.Event.addListener(window, "load", function() {
    var formatDuration = function(elLiner, oRecord, oColumn, oData) {
        if(oData) {
            elLiner.innerHTML = oData + 's';
        }
    };

    var formatEdit = function(elLiner, oRecord, oColumn, oData) {
        elLiner.innerHTML = '<a href="' + oData + '">Edit</a>';
    };

    var formatElevation = function(elLiner, oRecord, oColumn, oData) {
        if(oData) {
            elLiner.innerHTML = oData + 'm';
        }
    };

    var formatLatLng = function(elLiner, oRecord, oColumn, oData) {
        var lat = oRecord.getData("latitude");
        var lng = oRecord.getData("longitude");

        if(typeof lat == 'number' && typeof lng == 'number') {
            elLiner.innerHTML = lat.toFixed(3) + ' / ' + lng.toFixed(3);
        } else {
            elLiner.innerHTML = '';
        }
    };

    var formatPlay = function(elLiner, oRecord, oColumn, oData) {
        elLiner.innerHTML = '<a href="' + oData + '">Play</a>';
        var mp3 = oRecord.getData('MP3URL');

        // Tack on the MP3 URL if the file is not originally an MP3.
        if(mp3) {
            elLiner.innerHTML += '<a href="' + mp3 + '"></a>';
        }
    };

    var formatUser = function(elLiner, oRecord, oColumn, oData) {
        elLiner.innerHTML = '<a href="' + oRecord.getData("USERURL") + '">' + oData + '</a>';
    };

    var formatSpecies = function(elLiner, oRecord, oColumn, oData) {
        var listHTML = '<ul class="species">';

        for(var i in oData) {
            var s = oData[i];
            var d = species_descriptions[s.genus + ' ' + s.species];

            if(d) {
                // FIXME a bit hardwired.
                var url = soundfiles_ikiwiki_baseurl + 'Aves/species/' + s.genus + '_' + s.species + '/';

                listHTML += '<li><a href="' + url + '">'
                    + d.description + ' <em>' + s.genus + ' ' + s.species + '</em></a></li>';
            } else {
                listHTML += '<li><b>no description</b> <em>'
                    + s.genus + " " + s.species + '</em></a></li>';
            }
        }

        listHTML += '</ul>';
        elLiner.innerHTML = listHTML;
    };

    // FIXME why is this not fixed? -- it generates NaN in the
    // fields, even though I ask it to parse the data as dates.
    // FIXME specifying the locale here is crap.
    var formatDate = function(el, oRecord, oColumn, oData) {
        var oConfig = {format: "%Y/%m/%d"};

        // Awesomely nasty hackery.
        if(Object.prototype.toString.call(oData) === "[object Date]"
           && !isNaN(oData.getTime())) {
            el.innerHTML = YAHOO.util.Date.format(oData, oConfig, oConfig.locale);
        }
    };

    // FIXME get the Perl to generate this.
    var masterColumnDefs = [
        {key: "PLAYURL", label: "", resizeable: true, formatter: formatPlay },
        {key: "EDITURL", label: "", resizeable: true, formatter: formatEdit },
        {key: "latlng", label: "Latitude/Longitude", sortable: true, resizeable: true, formatter: formatLatLng },
        {key: "location", label: "Location", sortable: true, resizeable: true},
        {key: "date", label: "Date", sortable:true, sortOptions: {defaultDir:YAHOO.widget.DataTable.CLASS_DESC},
                        resizeable:true, formatter: formatDate },
        {key: "fg_species", label: "Foreground Species", sortable: true, resizeable: true, formatter: formatSpecies },
        {key: "recordingquality", label: "Quality", sortable: true, resizeable: true },
        {key: "duration", label: "Duration", sortable: true, resizeable: true, formatter: formatDuration }
    ];

    var nestedColumnDefs = [
        {key: "user", label: "User", sortable: true, resizeable: true, formatter: formatUser },
        {key: "recordist", label: "Recordist", sortable: true, resizeable: true},
        {key: "time", label: "Table", sortable: true, resizeable: true},
        {key: "elevation", label: "Elevation", sortable: true, resizeable: true, formatter: formatElevation },
        {key: "bg_species", label: "Background Species", sortable: true, resizeable: true, formatter: formatSpecies},
        {key: "notes", label: "Notes", resizeable: true}
    ];
    // This is the layout and types for the JS objects in our arrays.
    var fields = [ "index", "type", "user", "recordist", {key: "date", parser: "date"},
                   "time",
                   {key: "latitude", parser: 'number'},
                   {key: "longitude", parser: 'number'},
                   "location", "elevation", "duration", "recordingquality", "fg_species", "bg_species",
                   "notes", "PLAYURL", "MP3URL", "EDITURL", "USERURL" ];

    // FIXME can we handle multi-selection <ctrl> <shift>, etc?
    var rowClickCallBack = function(e, t) {
        if(typeof GOOGLEMAPS != 'undefined' && typeof GOOGLEMAPS.hilight != 'undefined') {
            var elTarget = e.target;
            var oRecord = this.getRecord(elTarget);
            var type = oRecord.getData("type");
            var id = oRecord.getData("index");

            array = (type === 'fg')
                ? fg_recordings
                : (type == 'bg')
                  ? bg_recordings
                  : user_recordings;
            GOOGLEMAPS.hilight(array[id]);
        }
    };

    // FIXME Quick hack that solves today's problem.
    var clone = function(obj) {
        if(obj == null || typeof(obj) != 'object')
            return obj;

        var temp = obj.constructor();

        for(var key in obj)
            temp[key] = clone(obj[key]);
        return temp;
    }

    var mkDataTable = function(div_id, recordings, recording_type, caption) {
        // FIXME number each recording so we can hilight the
        // corresponding table row.  Gotta be a better way to do
        // this.  FIXME using for(i in recordings) doesn't work!
        // The indices are objects, not numbers ?? and YUI gets confused.
        for(var i = 0; i < recordings.length; i++) {
            recordings[i].type = recording_type;
            recordings[i].index = i;
        };

        var ds = new YAHOO.util.DataSource(recordings);
        ds.responseType = YAHOO.util.DataSource.TYPE_JSARRAY;
        ds.responseSchema = { fields: fields };

        var opts = {};

        if(recordings.length > 10) {
            opts.paginator = new YAHOO.widget.Paginator({ rowsPerPage: 10 });
        }

        if(caption) {
            opts.caption = caption;
        }

        // Note we clone the masterColumnDefs as the NestedDataTable
        // code mutates it. This manifests as two columns of '+'
        // (expanders) in the second (background) table.
        var dt = new YAHOO.widget.NestedDataTable(div_id,
                                                  clone(masterColumnDefs), ds,
                                                  nestedColumnDefs, fields,
                                                  opts);

        dt.subscribe("rowMouseoverEvent", dt.onEventHighlightRow);
        dt.subscribe("rowMouseoutEvent", dt.onEventUnhighlightRow);
        dt.subscribe("rowClickEvent", dt.onEventSelectRow);
        dt.subscribe("rowClickEvent", rowClickCallBack);

        return { oDS: ds, oDT: dt };
    };

    if(typeof fg_recordings != 'undefined') {
        SOUNDFILES.fg = mkDataTable("fg_soundfiles", fg_recordings, 'fg', "Foreground Recordings");
    }
    if(typeof bg_recordings != 'undefined') {
        SOUNDFILES.bg = mkDataTable("bg_soundfiles", bg_recordings, 'bg', "Background Recordings");
    }
    if(typeof user_recordings != 'undefined') {
        SOUNDFILES.bg = mkDataTable("user_soundfiles", user_recordings, 'user');
    }

    // Hilight the given array of recording data.
    SOUNDFILES.hilight = function(rs) {
        // Why is this so hard?
        if(typeof SOUNDFILES.fg != 'undefined') {
            SOUNDFILES.fg.oDT.unselectAllRows();
        }
        if(typeof SOUNDFILES.bg != 'undefined') {
            SOUNDFILES.bg.oDT.unselectAllRows();
        }

        for(i in rs) {
            var r = rs[i];
            var o = null;

            // This is a bit crafty: the user table is SOUNDFILES.bg
            o = (r.type === 'fg') ? SOUNDFILES.fg : SOUNDFILES.bg;
            o.oDT.selectRow(r.index);
        }
    };
});
