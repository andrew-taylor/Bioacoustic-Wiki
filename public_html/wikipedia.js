// JavaScript boilerplate for the wikipedia grab plugin.
// peteg42 at gmail dot com, begun November 2009.

// Based on http://www.nihilogic.dk/labs/wikipedia_summary/sumbox.js
// which carries the following licence:

/*
 * Wiki Summary Box 0.1.2
 * Copyright (c) 2008 Jacob Seidelin, cupboy@gmail.com, http://blog.nihilogic.dk/
 * MIT License [http://www.opensource.org/licenses/mit-license.php]
 */

var __WikiCallbacks = {};

(function() {
    var callCount = 0;
    var footerGFDLText = "Available under the <a href=\"http://en.wikipedia.org/wiki/Wikipedia:Text_of_the_GNU_Free_Documentation_License\" target=\"_blank\">GNU Free Documentation License</a>.";

    var wikiSites =
        [
         {basehost : "wikipedia.org", lang : true, apipath : "/w/api.php", articlepath : "/wiki/", name : "Wikipedia", licensetext : footerGFDLText},
         {basehost : "wikiquote.org", lang : true, apipath : "/w/api.php", articlepath : "/wiki/", name : "Wikiquote", licensetext : footerGFDLText, fullarticle : false},
         {basehost : "species.wikimedia.org", lang : false, apipath : "/w/api.php", articlepath : "/wiki/", name : "Wikispecies", licensetext : footerGFDLText, fullarticle : true, css : "wikispecies"},
         {basehost : "wikinews.org", lang : true, apipath : "/w/api.php", articlepath : "/wiki/", name : "Wikinews", licensetext : footerGFDLText, fullarticle : false},
         {basehost : "wikisource.org", lang : true, apipath : "/w/api.php", articlepath : "/wiki/", name : "Wikisource", licensetext : footerGFDLText, fullarticle : false},
         {basehost : "wikibooks.org", lang : true, apipath : "/w/api.php", articlepath : "/wiki/", name : "Wikibooks", licensetext : footerGFDLText, fullarticle : false},
         {basehost : "wiktionary.org", lang : true, apipath : "/w/api.php", articlepath : "/wiki/", name : "Wiktionary", licensetext : footerGFDLText, fullarticle : true, css : "wiktionary"},
         {basehost : "wikiversity.org", lang : true, apipath : "/w/api.php", articlepath : "/wiki/", name : "Wikiversity", licensetext : footerGFDLText, fullarticle : false}
        ];

    // FIXME tidy
    function cleanLinks(node, baseurl) {
        if (!node.hasChildNodes) return;
        for (var i=0;i<node.childNodes.length;i++) {
            var child = node.childNodes[i];
            if (child.tagName == "A") {
                if (child.getAttribute("tmphref") && child.getAttribute("tmphref").substring(0,1) == "/") {
                    child.setAttribute("href", baseurl + child.getAttribute("tmphref"));
                    child.setAttribute("target", "_blank");
                }
            } else {
                if (child.hasChildNodes) {
                    cleanLinks(child, baseurl);
                }
            }
        }
        return node;
    };

    var dc = function(tag, className) {
        var el = document.createElement(tag);
        if (className)
            el.className = className;
        return el;
    };

    function wikiCallBack(elt, site, query, lang, res) {
        var baseurl = "http://"+ (site.lang ? (lang+"."+site.basehost) : site.basehost);

        var header = dc("div", "wiki-summary-header header");
        var content = dc("div", "wiki-summary-content");
        var footer = dc("div", "wiki-summary-footer footer");

        var rawContent = document.createElement("div");

        var rawHTML = res.parse.text["*"];

        // remove images, we don't want to leech off of the Wiki servers
        // rawHTML = rawHTML.replace(/\<img\ .*?\>/g, "");

        // Argh, this is no fun. IE won't let us get the relative
        // paths to other Wiki pages so we can't distinguish them from
        // other links.  This is all I could think of so far: replace
        // the href attribute with another temporary attribute and
        // then switch it back later when we're walking the DOM tree
        // of the Wiki content.
        rawContent.innerHTML = rawHTML.replace(/<a\ href\=\"/g, "<a tmphref=\"");

        var sumFragment = document.createDocumentFragment();

        if (site.fullarticle) {
            sumFragment.appendChild(cleanLinks(rawContent, baseurl));
        } else {
            var parNodes = [];
            for (var i=0;i<rawContent.childNodes.length;i++) {
                var node = rawContent.childNodes[i];
                if (node.tagName == "P") {
                    var text = node.textContent || node.innerHTML || "";
                    if (text.replace(/^\s*([\S\s]*?)\s*$/, '$1') == "") {
                        continue;
                    }
                    parNodes.push([node, rawContent]);
                }
                if (node.tagName == "UL" || node.tagName == "OL") {
                    for (var j=0;j<node.childNodes.length;j++) {
                        if (node.childNodes[j].tagName == "LI")
                            cleanLinks(node.childNodes[j], baseurl);
                    }
                    parNodes.push([node, rawContent]);
                }
                if (node.tagName == "H1" || node.tagName == "H2") {
                    break;
                }
            }
            for (var i=0;i<parNodes.length;i++) {
                if (parNodes[i][0] && parNodes[i][1]) {
                    parNodes[i][1].removeChild(parNodes[i][0]);
                    sumFragment.appendChild(cleanLinks(parNodes[i][0], baseurl));
                }
            }
        }

        content.innerHTML = "";
        content.appendChild(sumFragment);

        // Construct the header and footer.
        var wikiName = site.name;
        var wikiURL = "http://" + (site.lang ? (lang+"."+site.basehost) : site.basehost) + "/";
        var articleURL = "http://" + (site.lang ? (lang+"."+site.basehost) : site.basehost) + site.articlepath + query;

        header.innerHTML = '<h2><a href="' + wikiURL + '">' + wikiName
            + '</a>: <a href="' + articleURL
            + '">'
            + decodeURIComponent(query).replace(/_/g, ' ') + '</a></h2>';
        footer.innerHTML = site.licensetext;

        // Clear the div: removes the static 'Loading...'.
        while (elt.firstChild) {
            elt.removeChild(elt.firstChild);
        }

        elt.appendChild(header);
        elt.appendChild(content);
        elt.appendChild(footer);
    }

    // FIXME straighten this out.
    function requestPage(elt, site, query, lang, page) {
        callCount++;

        var url = "http://" + (site.lang ? (lang+"."+site.basehost) : site.basehost) + site.apipath + "?action=parse&prop=text&format=json&redirects&callback=__WikiCallbacks.fn_" + callCount + "&page=" + page;
        var script = document.createElement("script");

        __WikiCallbacks['fn_' + callCount] = function(res) {
            document.body.removeChild(script);
            wikiCallBack(elt, site, query, lang, res);
        };

        script.setAttribute('type', 'text/javascript');
        script.setAttribute('src', url);

        document.body.appendChild(script);
    };

    function searchRequest(elt, site, query, lang) {
        lang = lang || "en";

        callCount++;

        var url = "http://" + (site.lang ? (lang+"."+site.basehost) : site.basehost) + site.apipath + "?action=opensearch&limit=1&callback=__WikiCallbacks.fn_" + callCount + '&search=' + query;
        var script = document.createElement("script");

        __WikiCallbacks['fn_' + callCount] = function(res) {
            document.body.removeChild(script);
            // Extract the search response
            requestPage(elt, site, query, lang, res[1][0]);
        };

        script.setAttribute('type', 'text/javascript');
        script.setAttribute('src', url);

        document.body.appendChild(script);
    }

    // Find all divs that we should fill with wiki grabs.
    var site = wikiSites[0]; // use wikipedia
    var lang;
    var idPrefix = 'wikipedia_content_';
    var allDivs = document.getElementsByTagName('div');

    for(var i in allDivs) {
        var elt = allDivs[i];
        var eltId = elt.id;

        if(eltId && eltId.substr(0, idPrefix.length) === idPrefix) {
            var query = eltId.slice(idPrefix.length);

            searchRequest(elt, site, query, lang);
        }
    }
})();
