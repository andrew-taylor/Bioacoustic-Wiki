// JavaScript for species taxonomy navigation.
// peteg42 at gmail dot com, begun July 2010.

// Relies of YUI's TreeView.

YAHOO.util.Event.addListener(window, "load", function() {
    var tree = new YAHOO.widget.TreeView("species_tree", species_tree_data);
    tree.singleNodeHighlight = true;

    // Supress the expand-on-label-click behavior.
    // Makes the hrefs work in the labels.
    tree.subscribe('clickEvent', function(event, node) {
        YAHOO.util.Event.preventDefault(event);
        return false;
    });

    // If a node has fewer than a certain number of children, expand
    // the whole thing. If it has a single child, expand that.
    tree.subscribe('expand', function(node) {
        if(node.getNodeCount() < 20) {
            node.expandAll();
        } else if(node.children.length == 1) {
            node.children[0].expand();
        }
    });

    // Scrape the URL: if it's a taxonomy node or species page, open
    // the tree up at that node.
    // e.g. .../Aves/taxonomy/Gruiformes/Gruidae/Grus/
    var re = /(Aves\/(species|taxonomy)\/.+?)\/?([#?].*)?$/;
    var matches = location.href.match(re);

    if(matches && matches.length >= 2) {
        var node = tree.getNodeByProperty("page", matches[1]);
        if(node) {
            node.highlight();

            while(node) {
                node.expand();
                node = node.parent;
            }
        }
    }

    tree.draw();
});
