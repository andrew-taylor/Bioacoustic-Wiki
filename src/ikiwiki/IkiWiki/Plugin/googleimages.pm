#!/usr/bin/perl
# Ikiwiki google image search API plugin
# peteg42 at gmail dot com, begun November 2009.
package IkiWiki::Plugin::googleimages;

use warnings;
use strict;
use IkiWiki 3.00;

sub import {
    add_underlay('javascript');

    hook(type => 'getsetup', id => 'googleimages', call => \&getsetup);
    hook(type => 'preprocess', id => 'googleimages', call => \&preprocess);
    hook(type => 'format', id => 'googleimages', call => \&format);
}

sub getsetup () {
    return
        plugin => {
            description => 'Embed Google image search results on wiki pages.',
            safe => 1,
            rebuild => 0
        },
        googleimages_key => {
            type => 'string',
            description => 'Google Maps key',
            example => 'ABQIAAAAa2F4nJ-WIrk6lQCWEaykgRRIfr-7gXkV8p1x5LUvHIt_M1ecGxSod5HoLO6wDvD2WB9O_VqNtY57EQ',
            safe => 1,
            rebuild => 1
        }
}

sub preprocess {
    my %params = @_;
    my $page = $params{page};
    my $html;

    foreach my $required (qw{query}) {
        if (! exists $params{$required}) {
            error sprintf(gettext("missing %s parameter"), $required)
        }
    }

    my $template = template_depends("googleimages.tmpl", $page, blind_cache => 1);
    $template->param(query => $params{query});
    return $template->output;
}

# Graft the JavaScript loader code onto pages with image searches.
sub format (@) {
    my %params = @_;

    my %js_params;

    if($params{content} =~ m!<div class=".*googleimages_container.*".*?>!) {
        $params{content} =~ s!<p class="javascript">(.*)</p>!<script type="text/javascript">$1</script>!g;

        # Add the javascript at the end of the file (best practice).
        if (!($params{content} =~s !(</body>)!include_javascript(%js_params).$1!em)) {
            # no </body> tag, probably in preview mode
            $params{content} .= include_javascript(%js_params);
        }
    }

    return $params{content};
}

sub include_javascript {
    my %params = @_;
    my $key = $config{googleimages_key};

    return '<script src="http://www.google.com/jsapi?key=' . $key .
                  '" type="text/javascript"></script>' .
           '<script type="text/javascript">google.load("search", "1");</script>' .
           '<script src="'.urlto('googleimages.js', '', 1)
                  . '" type="text/javascript"></script>';
}

1;
