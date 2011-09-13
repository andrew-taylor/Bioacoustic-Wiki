// JavaScript boilerplate for the google image search API plugin.
// peteg42 at gmail dot com, begun November 2009.
// Based on http://www.google.com/uds/samples/apidocs/image.html

// Assumes we get called late in the day (best practice).

(function() {
    var searchDiv = document.getElementById("googleimages_searchControl");
    var searchControl = new google.search.SearchControl(null);

    searchControl.setResultSetSize(google.search.Search.LARGE_RESULTSET);

    var searchOptions = new google.search.SearcherOptions();
    searchOptions.setExpandMode(google.search.SearchControl.EXPAND_MODE_OPEN);

    searchControl.addSearcher(new google.search.ImageSearch(), searchOptions);

    var drawOptions = new google.search.DrawOptions();

    searchControl.draw(searchDiv, drawOptions);

    // execute a starter search
    searchControl.execute(googleimages_initial_query);
})();
