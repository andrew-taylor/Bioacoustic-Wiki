#!/usr/bin/perl
# Ikiwiki taxonomy metadata plugin
# peteg42 at gmail dot com, begun November 2009.
package IkiWiki::Plugin::taxonomy;

use warnings;
use strict;
use IkiWiki 3.00;
use File::Spec;
use JSON;

use File::Glob ':glob';

my $taxonomy_description_filename = 'taxonomy_description_data.js';
my $taxonomy_tree_filename = 'taxonomy_tree_data.js';
my $taxonomy_js = 'taxonomy.js';
my $species_class = 'Aves';
my $taxonomy_root_page = "$species_class/taxonomy";

sub description_filename {
    return $taxonomy_description_filename;
}

sub species_page {
    my ($genus, $species) = @_;

    if($species) {
        return "${species_class}/species/${genus}_${species}";
    } elsif($genus) {
        # FIXME small HACK, give a partial page name.
        return "${species_class}/species/${genus}_";
    } else {
        # FIXME small HACK, give a partial page name.
        return "${species_class}/species";
    }
}

=pod

    FIXME Maps species page names to genus page names (leaf nodes in
    the taxonomy tree).

=cut
sub taxa_parent {
    my ($species_page) = @_;

    return $pagestate{$species_page}{taxonomy}{taxa_parent};
}

=pod

Tracks species information pages.

Integrates the set-page-title functionality of the meta plugin.

Maintains a mapping from pages to scientific names in $pagestate.
Maintains a mapping from scientific name to descriptions (common names, etc.) in %wikistate.

On rebuild we dispose of the stuff in %wikistate.

On savestate we generate the javascript autocomplete file.

Maintains the autocompletion data for species.

=cut

sub import {
    add_underlay('javascript');

    hook(type => 'canremove', id => 'taxonomy', call => \&canremove);
    hook(type => 'canrename', id => 'taxonomy', call => \&canrename);
    hook(type => 'delete', id => 'taxonomy', call => \&delete);
    hook(type => 'format', id => 'taxonomy', call => \&format);
    hook(type => "getsetup", id => "taxonomy", call => \&getsetup);
    hook(type => "needsbuild", id => "taxonomy", call => \&needsbuild);
    hook(type => "preprocess", id => "taxonomy", call => \&preprocess, scan => 1);
    hook(type => "pagetemplate", id => "taxonomy", call => \&pagetemplate);
    hook(type => "savestate", id => "taxonomy", call => \&savestate);
}

sub getsetup {
    return
        plugin => {
            safe => 1,
            rebuild => 1,
    },
}

sub needsbuild (@) {
    my ($files, $deleted_files) = @_;

    # use Data::Dumper;
    # warn "taxonomy::needsbuild start files: " . Data::Dumper::Dumper($files);

    if($config{rebuild}) {
        warn 'taxonomy: dropping autocomplete data on the floor.';
        delete $wikistate{taxonomy};
    }

    # If we're rebuilding, dependencies don't matter.

    # FIXME this probably implies that taxonomy tree changes require
    # full rebuilds, as we use potentially-stale taxonomy tree info
    # here.

    if(! $config{rebuild}) {
        # Otherwise we're doing an update, so we can assume
        # $wikistate{taxonomy} is populated.

        # FIXME add in taxa nodes that have changed species pages/maps/soundfiles/...
        # Roughly if species/(.*)_(.*) appears in $files, find that genus
        # and rebuild everything back to the root.

        my $species_root = species_page();
        foreach my $species_page_alias (grep { m!^($species_root/\w+_\w+)(/|\.)! } (@{$files}, @{$deleted_files})) {
            warn "taxonony needsbuild dependencies: '$species_page_alias'";
            $species_page_alias =~ m!^($species_root/\w+_\w+)(/|\.)!;
            my $species_page = $1;

            # FIXME this is a bit of a hack. It doesn't work well with
            # deletions, e.g. after a wiki rebuild, if the soundfile
            # isn't touched until it is deleted, the dependent pages
            # don't get rebuilt.

            my $taxa_page = taxa_parent($species_page);

            # FIXME be a bit ginger here.
            if(!$taxa_page) {
                warn "taxonomy::needsbuild: Missing taxa_parent for '$species_page', skipping.";
                next;
            } elsif(!($taxa_page =~ m!/taxonomy/!)) {
                warn "taxonomy::needsbuild: Invalid taxa_parent for '$species_page': '$taxa_page', skipping.";
                next;
            }

            # Do this for each level in the taxonomy. FIXME nasty.
            while(1) {
                # FIXME adding things to $files doesn't seem to work (cause the files to be regenerated).
                # Adding a dependency does, though.
                warn "  tax: adding dependency '$taxa_page' -> '$species_page_alias' ";
                add_depends($taxa_page, $species_page_alias);

                # FIXME NEW: also add to $files. Belt and suspenders...
                # Add each page once only.
                my $taxa_page_filename = $taxa_page . ".mdwn";
                push @{$files}, $taxa_page_filename
                    unless grep { /^$taxa_page_filename$/ } @{$files};

                last if $taxa_page =~ m!/taxonomy$!;

                # Toss the rightmost component.
                $taxa_page =~ s!/[^/]*$!!;
            }
        }
    }

    # FIXME toss the taxonomy info for the pages we're rebuilding.
    # Note we do that /after/ using the possibly stale dependency information.
    foreach my $page (keys %pagestate) {
        if (exists $pagestate{$page}{taxonomy}) {
            if (exists $pagesources{$page} &&
                grep { $_ eq $pagesources{$page} } @{$files}) {

                # remove state, it will be re-added
                # if the preprocessor directive is still
                # there during the rebuild
                delete $pagestate{$page}{taxonomy};
            }
        }
    }

    # use Data::Dumper;
    # warn "taxonomy::needsbuild end files: " . Data::Dumper::Dumper($files);

    return $files;
}

=pod

    Handle renaming of pages via the web interface.

    *** Note this doesn't handle renames via the git interface. FIXME
    the wiki must be entirely rebuilt for those. ***

    This hook gets called after all the basic sanity checks, so we
    should be able to assume that the rename will succeed.

=cut
sub canrename {
    my %p = @_;
    # source and destination page names
    my $src = $p{src};
    my $dest = $p{dest};

    # Ignore the first check, before the renaming form is shown.
    return undef unless $dest;

    # Move the cache info for $src to $dest.
    if($src =~ m!/taxonomy/(\w+)/(\w+)/(\w+)$!) {
        my ($order, $family, $genus) = ($1, $2, $3);

        if(!($dest =~ m!/taxonomy/(\w+)/(\w+)/(\w+)$!)) {
            return "'$src' is a page for a genus, '$dest' is not.";
        }
        my ($n_order, $n_family, $n_genus) = ($1, $2, $3);

        # FIXME The rename operation might create a new order and family.
        if($n_order ne $order || $n_family ne $family) {
            return "FIXME '$src' and '$dest' are in different orders or families.";
        }

        #$wikistate{taxonomy}{order}{$n_order} = $wikistate{taxonomy}{order}{$order};
        #$wikistate{taxonomy}{family}{$n_family} = $wikistate{taxonomy}{family}{$family};
        $wikistate{taxonomy}{genus}{$n_genus} = $wikistate{taxonomy}{genus}{$genus};
        # FIXME if the rename fails, this is dangerous.
        delete $wikistate{taxonomy}{genus}{$genus};

        # Rename all the species files too.
        my $species_genus_pages = species_page($genus);
        foreach my $species_page_filename (bsd_glob("$config{srcdir}/${species_genus_pages}*")) {
            $species_page_filename =~ m!/(\w+)_(\w+)\.mdwn$!;
            my $species = $2;
            my $new_species_page_filename = $species_page_filename;
            $new_species_page_filename =~ s!/[^/]$!!;
            $new_species_page_filename .= "/${n_genus}_${species}.mdwn";

            warn "Renaming species page '$species_page_filename' -> '$new_species_page_filename'";

            IkiWiki::rcs_rename($species_page_filename, $new_species_page_filename);

            my $species_page = $new_species_page_filename;
            $species_page =~ s!\.mdwn$!!;

            warn "taxonomy rename: add_link '$dest' -> '$species_page'";
            add_link($dest, $species_page, 'taxonomy');
            # FIXME if backlinks were usable, we wouldn't need to do this.
            $pagestate{$species_page}{taxonomy}{taxa_parent} = $dest;
        }

        return '';
    } elsif($src =~ m!/taxonomy/(\w+)/(\w+)$!) {
        my ($order, $family) = ($1, $2);

        if(!($dest =~ m!/taxonomy/(\w+)/(\w+)$!)) {
            return "'$src' is a page for a family, '$dest' is not.";
        }
        my ($n_order, $n_family) = ($1, $2);

        # FIXME The rename operation might create a new order.
        if($n_order ne $order) {
            return "FIXME '$src' and '$dest' are in different orders.";
        }

        #$wikistate{taxonomy}{order}{$n_order} = $wikistate{taxonomy}{order}{$order};
        $wikistate{taxonomy}{family}{$n_family} = $wikistate{taxonomy}{family}{$family};
        # FIXME if the rename fails, this is dangerous.
        delete $wikistate{taxonomy}{family}{$family};

        # FIXME get this right.
        my $parent_page = $dest;
        $parent_page =~ s!/[^/]*$!!;
        add_link($parent_page, $dest, 'taxonomy');

        return '';
    } elsif($src =~ m!/taxonomy/(\w+)$!) {
        my ($order) = ($1);

        if(!($dest =~ m!/taxonomy/(\w+)$!)) {
            return "'$src' is a page for an order, '$dest' is not.";
        }
        my $n_order = $1;

        $wikistate{taxonomy}{order}{$n_order} = $wikistate{taxonomy}{order}{$order};

        # This is safe: if the rename fails, we don't commit
        # %wikistate to disk.
        delete $wikistate{taxonomy}{order}{$order};

        # FIXME get this right.
        my $parent_page = $p{dest};
        $parent_page =~ s!/[^/]+$!!;
        add_link($parent_page, $p{dest}, 'taxonomy');

        return '';
    } elsif($src =~ m!/species/(\w+)_(\w+)$!) {
        my ($genus, $species) = ($1, $2);

        if(!($dest =~ m!/species/(\w+)_(\w+)$!)) {
            return "'$src' is a page for a species, '$dest' is not.";
        }
        my ($n_genus, $n_species) = ($1, $2);

# Ensure the new genus exists.
# Add a context menu to the taxonomy widget for creating new pages.

        # This is safe: if the rename fails, we don't commit
        # %wikistate to disk.
        $wikistate{taxonomy}{species}{$n_genus}{$n_species} =
            $wikistate{taxonomy}{species}{$genus}{$species};
        delete $wikistate{taxonomy}{species}{$genus}{$species};

        # FIXME mend the pointer to the genus. This might get stomped
        # by some later process.
        $pagestate{$dest}{taxonomy}{taxa_parent} =
            $pagestate{$src}{taxonomy}{taxa_parent};

        return '';
    }
}

=pod

    Only taxonomy nodes with no children can be deleted.

=cut
sub canremove {
    my %p = @_;
    my $page = $p{page};

    if($page =~ m!/taxonomy(/|$)!) {
        my $proceed = 0;

        # Handle genera (leaf nodes in the taxonomy tree representation)
        if($page =~ m!/taxonomy/(\w+)/(\w+)/(\w+)$!) {
            my ($order, $family, $genus) = ($1, $2, $3);

            $proceed = ! $wikistate{taxonomy}{species}{$genus}
                    || ! %{$wikistate{taxonomy}{species}{$genus}};
        } else {
            my @subpages = bsd_glob("$config{srcdir}/$page/*");

            use Data::Dumper;
            warn "taxonomy::canremove '$page' subpages: " . Data::Dumper::Dumper(\@subpages);

            $proceed = ! @subpages;
        }

        my $deny = "Taxonomy node '$page' has children. These children must be removed first.";
        return ($proceed ? undef : $deny);
    }

    return undef;
}

=pod

    Remove the deleted page's information from
    %wikistate. Specifically remove species info and FIXME force a
    rebuild of the autocompletion data.

=cut
sub delete {
    my @files = @_;

    use Data::Dumper;
    warn "taxonomy::delete: " . Data::Dumper::Dumper(\@files);

    foreach my $file (@files) {
        # FIXME do we need to rebuild ancestor nodes?
        # FIXME mdwn hardwired here.
        my $page = $file;
        $page =~ s!\.mdwn$!!;

        if($page =~ m!/taxonomy/(\w+)/(\w+)/(\w+)$!) {
            my ($order, $family, $genus) = ($1, $2, $3);

            delete $wikistate{taxonomy}{genus}{$genus};
            warn "taxonomy::delete genus '$genus'";
        } elsif($page =~ m!/taxonomy/(\w+)/(\w+)$!) {
            my ($order, $family) = ($1, $2);

            delete $wikistate{taxonomy}{family}{$family};
            warn "taxonomy::delete family '$family'";
        } elsif($page =~ m!/taxonomy/(\w+)$!) {
            my ($order) = ($1);

            delete $wikistate{taxonomy}{order}{$order};
            warn "taxonomy::delete order '$order'";
        } elsif($page =~ m!/species/(\w+)_(\w+)$!) {
            my ($genus, $species) = ($1, $2);

            # $pagestate{$page} gets discarded by IkiWiki's deletion
            # mechanism.
            delete $wikistate{taxonomy}{species}{$genus}{$species};
            warn "taxonomy::delete species '$species'";
        }
    }
}

########################################
# Preprocess hook.

=pod

If the page is under $class/taxonomy, unpack the page name to figure
out what kind of taxonomy node it is. FIXME this needs tweaking for
other taxonomy structures.

=cut
sub preprocess {
    return "" unless @_;

    my %params = @_;
    my $page = $params{page};

    if($page =~ m!/taxonomy/(\w+)/(\w+)/(\w+)$!) {
        my ($order, $family, $genus) = ($1, $2, $3);

        debug "species.preprocess: tax node '$page': '$order' '$family' '$genus' description: '$params{description}'";

        # FIXME get this right.
        my $parent_page = $page;
        $parent_page =~ s!/[^/]+$!!;
        add_link($parent_page, $page, 'taxonomy');

        # Also say that there is a link from this page to all the species pages.
        my $species_genus_pages = species_page($genus);
        foreach my $species_page_filename (bsd_glob("$config{srcdir}/${species_genus_pages}*")) {
            $species_page_filename =~ m!(${species_genus_pages}\w+)\.mdwn$!;
            my $species_page = $1;

            # warn "taxonomy preprocess add_link '$page' -> '$species_page1'";
            add_link($page, $species_page, 'taxonomy');
            # FIXME if backlinks were usable, we wouldn't need to do this.
            $pagestate{$species_page}{taxonomy}{taxa_parent} = $page;
        }

        if($params{description}) {
            $wikistate{taxonomy}{genus}{$genus} = $params{description};
        }
    } elsif($page =~ m!/taxonomy/(\w+)/(\w+)$!) {
        my ($order, $family) = ($1, $2);

        debug "species.preprocess: tax node '$page': '$order' '$family' description: '$params{description}'";

        # FIXME get this right.
        my $parent_page = $page;
        $parent_page =~ s!/[^/]+$!!;
        add_link($parent_page, $page, 'taxonomy');

        if($params{description}) {
            $wikistate{taxonomy}{family}{$family} = $params{description};
        }
    } elsif($page =~ m!/taxonomy/(\w*)$!) {
        my ($order) = ($1);

        debug "species.preprocess: tax node '$page': '$order' description: '$params{description}'";

        my $parent_page = $page;
        $parent_page =~ s!/[^/]+$!!;
        add_link($parent_page, $page, 'taxonomy');

        if($params{description}) {
            $wikistate{taxonomy}{order}{$order} = $params{description};
        }
    } elsif($page =~ m!/species/(\w*)_(\w*)$!) {
        my ($genus, $species) = ($1, $2);

        debug "species.preprocess: species page: '$page' '$genus' '$species' description: '$params{description}'";

        if($params{description}) {
            $pagestate{$page}{taxonomy}{genus} = $genus;
            $pagestate{$page}{taxonomy}{species} = $species;

            # FIXME is this enough data?
            $wikistate{taxonomy}{species}{$genus}{$species} = $params{description};
        }
    }

    # Page title and heading.
    # FIXME HTML entities, see the meta plugin
    # FIXME what if we don't have a description?
    # Metadata collection that needs to happen during the scan pass.
    if($page =~ m!/species/(\w*)_(\w*)$!) {
        my ($genus, $species) = ($1, $2);

        my $description = $params{description};
        my $sci_name = "$genus $species";

        $pagestate{$page}{taxonomy}{title} = "$description <span class=\"tax_species\">$sci_name</span>";
        $pagestate{$page}{taxonomy}{headtitle} = "$description - $sci_name";
    } elsif($page =~ m!/taxonomy/!) {
        my $pageheading = IkiWiki::basename($page) . ' - ' . $params{description};

        $pagestate{$page}{taxonomy}{title} = $pageheading;
        $pagestate{$page}{taxonomy}{headtitle} = $pageheading;
    }

    # FIXME For other pages with a [[!taxonomy]] directive, we ignore
    # the parameters.

    # Signal our intention to write these two files.
    # FIXME better to say it too many times rather than not enough...
    IkiWiki::will_render($page, $taxonomy_description_filename, 1);
    IkiWiki::will_render($page, $taxonomy_tree_filename, 1);

    # In any case expand the [[!taxonomy]] directive itself.
    my $template = template_depends("taxonomy.tmpl", $page, blind_cache => 1);
    $template->param(taxonomy_root_url => urlto($taxonomy_root_page, '', 1));
    return $template->output;
}

sub pagetemplate {
    my %params = @_;
    my $page = $params{page};
    my $destpage = $params{destpage};
    my $template = $params{template};

    if (exists $pagestate{$page}{taxonomy}{title} && $template->query(name => "title")) {
        $template->param(headtitle => $pagestate{$page}{taxonomy}{headtitle});
        $template->param(title => $pagestate{$page}{taxonomy}{title});
        $template->param(title_overridden => 1);
    }
}

sub match {
    my $field=shift;
    my $page=shift;

    # turn glob into a safe regexp
    my $re=IkiWiki::glob2re(shift);

    my $val;
    if (exists $pagestate{$page}{taxonomy}{$field}) {
        $val=$pagestate{$page}{taxonomy}{$field};
    } elsif($field eq 'title') {
        $val = pagetitle($page);
    }

    if (defined $val) {
        if ($val=~/^$re$/i) {
            return IkiWiki::SuccessReason->new("$re matches $field of $page");
        } else {
            return IkiWiki::FailReason->new("$re does not match $field of $page");
        }
    } else {
        return IkiWiki::FailReason->new("$page does not have a $field");
    }
}

########################################
# Traverse the taxonomy tree.

=pod

Walks the taxonomy directory tree.

FIXME this doesn't account for the desired ordering of taxonomy
nodes. Keep that order in a file?

Memoise the intermediate results so the traversal order doesn't matter
so much.

FIXME Whenever a species page changes the entire tree gets traversed,
as we need to rebuild the top-level taxonomy page's range map
(etc). Could ameliorate this by storing the cache in the pagestate
hash...

FIXME only memo the taxa nodes, not the species pages.

=cut
sub traverse_taxonomy_tree {
    my ($root_page, $species_fn, $node_fn, $memo) = @_;
    my %succ_map = ( class => 'order', order => 'family', family => 'genus', genus => 'species' );

    # Ha, in your face Perl!
    my $f;
    $f = sub {
        my %p = @_;
        my $type = $p{type};
        my $page = $p{page};

        die "FIXME PAGE UNDEFINED" if !defined $page or $page eq '';

        return $memo->{$page} if $memo->{$page};

        $page =~ m!/([^/]*)$!;
        my $label = $1;

        if($type eq 'genus') {
            # Bottomed out. Traverse the genus.
            my $genus = $label;

            # warn "Looking at '$type' '$genus'";

            # FIXME ordering.
            my @children = map { &$species_fn(genus => $genus, species => $_); }
                               (sort (keys %{$wikistate{taxonomy}{species}{$genus}}));
            my $node = &$node_fn(children => \@children, label => $label, page => $page, type => $type);
            $memo->{$page} = $node;
            return $node;
        } else {
            # warn "traverse_taxonomy_tree / node: Looking at '$type' '$label'";

            my $g = sub {
                my ($tax_file_canonical) = @_;
                $tax_file_canonical =~ m!/(\w+)\.mdwn!;
                my $relative = $1;

                return &$f(type => $succ_map{$type}, page => "$page/$relative" );
            };

            # FIXME hopefully this is in creation order and hopefully
            # that is OK...
            # FIXME this is a little grot.
            my @children = map { &$g($_); }
                               bsd_glob("$config{srcdir}/$page/*.mdwn", GLOB_NOSORT);

            my $node = &$node_fn(children => \@children, label => $label, page => $page, type => $type);
            $memo->{$page} = $node;
            return $node;
        }
    };

    # Calculate the page type as a function of depth in the taxonomy.
    # FIXME totally flimsy, assumes $root_page is under /taxonomy/

    die "traverse_taxonomy_tree: '$root_page' is not a taxonomy node."
        if ! $root_page =~ m!/taxonomy!;

    my $type = 'class';
    my $t = $root_page;

    while(!($t =~ m!/taxonomy$!)) {
        #warn " >> '$t' type: '$type'";
        $t =~ s!/[^/]*$!!;
        $type = $succ_map{$type};
    }

    #warn "traverse_taxonomy_tree '$t' '$root_page' type: '$type'";

    return &$f(type => $type, page => $root_page);
}

########################################

=pod

Build the taxonomy tree as a JavaScript (JSON) object literal.

=cut
sub mk_taxonomy_tree {
    my $render_soundfiles = sub {
        my ($num_soundfiles) = @_;
        my ($bg, $fg) = @{$num_soundfiles};

        return $bg + $fg > 0
            ? ' <span class="num_soundfiles">(' . $fg . 'F, ' . $bg . 'B)</span>'
            : '';
    };

    my $node_fn = sub {
        my %p = @_;

        # warn "mk_taxonomy_tree node_fn: looking at '$p{page}'";

        my $bg = 0;
        my $fg = 0;
        map { $bg += @{$_->{num_soundfiles}}[0]; $fg += @{$_->{num_soundfiles}}[1]; }
            @{$p{children}};
        my $num_soundfiles = [$bg, $fg];

        # FIXME maybe use a template here.
        my $html = "<a href=\""
            . urlto("$p{page}", '', 1)
            . "\" class=\"tax_$p{type}\">$p{label}</a>";
        $html .= &$render_soundfiles($num_soundfiles);
        $html .= ' ' . $wikistate{taxonomy}{$p{type}}{$p{label}}
          if defined $wikistate{taxonomy}{$p{type}}{$p{label}};

        return { type => 'html',
                 html => $html,
                 page => $p{page},
                 num_soundfiles => $num_soundfiles,
                 children => $p{children} };
    };

    my $species_fn = sub {
        my %p = @_;
        my $genus = $p{genus};
        my $species = $p{species};

        # warn "mk_taxonomy_tree species_fn: looking at '$genus' '$species'";

        my $num_soundfiles = IkiWiki::Plugin::soundfiles::count_soundfiles($genus, $species);

        my $html = "<a href=\"" . scientific_name_href($genus, $species) . "\" class=\"tax_species\">$genus $species</a>";
        $html .= &$render_soundfiles($num_soundfiles);
        $html = $wikistate{taxonomy}{species}{$genus}{$species} . ' ' . $html
            if defined $wikistate{taxonomy}{species}{$genus}{$species};

        return { type => 'html',
                 html => $html,
                 page => species_page($genus, $species),
                 num_soundfiles => $num_soundfiles };
    };

    # Discard the top-level "taxonomy" node.
    my %memo;
    my $tax_tree = traverse_taxonomy_tree($taxonomy_root_page, $species_fn, $node_fn, \%memo)->{children};

    my $json = JSON->new;
    my $content = "var species_tree_data =\n" . $json->encode($tax_tree);
    writefile($taxonomy_tree_filename, $config{destdir}, $content);
}

sub savestate {
    # Regenerate the autocompletion file completely.
    # FIXME difficult to optimise.
    # FIXME it seems to do this on every wiki refresh. Restrict it to rebuilds ?? descriptions could change.

    my $acf_canonical = File::Spec->catdir($config{destdir}, $taxonomy_description_filename);

    debug "Species savestate: $acf_canonical";

    open(my $fh, '>', $acf_canonical)
        or error "Can't create '$acf_canonical'";
    print $fh <<EOF;
var species_descriptions =
	{
EOF
    my $id = 0;

    foreach my $genus (keys %{$wikistate{taxonomy}{species}}) {
        foreach my $species (keys %{$wikistate{taxonomy}{species}{$genus}}) {
            my $description = $wikistate{taxonomy}{species}{$genus}{$species};

            print $fh <<EOF;
"${genus} ${species}": {id: $id, genus: "$genus", species: "$species", description: "$description"},
EOF
            $id++;
        }
    }

    print $fh <<EOF;
};
EOF
    close $fh;

    mk_taxonomy_tree();
}

# FIXME a bit redundant.
sub scientific_name_href {
    my ($genus, $species) = @_;
    return urlto(species_page($genus, $species), '', 1);
}

# FIXME this is from meta. Perhaps it does something more than cause warnings.

# package IkiWiki::PageSpec;

# sub match_title ($$;@) {
# 	IkiWiki::Plugin::species::match("title", @_);
# }

sub format {
    my %params = @_;

    if($params{content} =~ /div(.*)id=\"species_tree\"/) {
        # Add the javascript at the end of the file (best practice).
        if (!($params{content} =~s !(</body>)!include_javascript().$1!em)) {
            # no </body> tag, probably in preview mode
            $params{content} .= include_javascript();
        }
    }

    return $params{content};
}

sub include_javascript {
    return
        '<script type="text/javascript" src="http://yui.yahooapis.com/combo?2.8.1/build/yahoo-dom-event/yahoo-dom-event.js&amp;2.8.1/build/treeview/treeview-min.js"></script>'
      . '<script src="' . urlto($taxonomy_tree_filename, '', 1)
                        . '" type="text/javascript"></script>'
      . '<script src="' . urlto($taxonomy_js, '', 1) # 1 -> absolute URL
                        . '" type="text/javascript"></script>';
}

1;
