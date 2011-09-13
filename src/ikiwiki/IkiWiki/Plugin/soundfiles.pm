#!/usr/bin/perl

=pod

Upload and manage sound file info for the bioacoustics wiki.

peteg42 at gmail dot com, begun August 2009.

Two parts:
 - per-user management of sound files.
 - per-species and per-user lists of sound files

=cut

package IkiWiki::Plugin::soundfiles;

use warnings;
use strict;
use HTML::Entities;
use IkiWiki 3.00;
use IkiWiki::Render;

use Fcntl;
use Fcntl ':flock';
use File::Copy qw//;
use File::Path qw/ mkpath /;
use File::Spec;
use Cwd 'abs_path'; # Path canonicalisation

use CGI::FormBuilder;

# Hash filenames
use Digest::SHA qw/ sha384_hex /;

# Sound file metadata is stored in JSON
use JSON qw//;
my $metadata_ext = 'json';

# Constants
my $foreground = 'fg';
my $background = 'bg';
my @recording_quality = qw/A B C D E/;

# ISO YYYY/MM/DD format
my $date_re = '/^[0-9]{4}\/?(0?[1-9]|1[0-2])\/?(0?[1-9]|[1-2][0-9]|3[0-1])$/';
my $time_re = '/^(20|21|22|23|[01]\d|\d)([:][0-5]\d)?$/';
# Limit the length of the notes field.
my $notes_re = '/.{0,10000}/';

# Key in the userdb for persistent defaults for uploads.
my $soundfiles_defaults = 'soundfiles_defaults';

# Hardwire in a map of mime subtypes to file extensions.
# FIXME don't support mp4s as Flash/sox don't.
my %audio_file_exts =
    ( 'x-flac' => 'flac',
      'x-wav' => 'wav',
      'mpeg' => 'mp3',
#      'mp4' => 'm4a',
    );

# Whitelisted metadata fields, the ones we retain when the user
# submits the edit/upload form. We process the filename and species
# lists. Remember to tweak show_form() and templates.
my @metadata_field_whitelist
    = qw / date time latitude longitude location elevation
           recordist recordingquality notes /;

my $edit_action = 'edit_soundfile';
my $upload_action = 'upload_soundfiles';

=pod
    my $filename = user_page('user');

Name of a user's page relative to $config{srcdir}.

=cut
sub user_file {
    my ($user) = @_;

    return $user;
}

sub import {
    # Species name management.
    IkiWiki::loadplugin('taxonomy');

    # Configuration
    hook(type => 'getsetup', id => 'soundfiles', call => \&getsetup);
    hook(type => 'checkconfig', id => 'soundfiles', call => \&checkconfig);

    # File upload
    add_underlay('javascript');
    hook(type => 'canrename', id => 'soundfiles', call => \&canrename);
    hook(type => 'needsbuild', id => 'soundfiles', call => \&needsbuild);
    hook(type => 'sessioncgi', id => 'soundfiles', call => \&sessioncgi);

    IkiWiki::loadplugin('googlemaps');
    IkiWiki::loadplugin('filecheck');

    # Expand [[!soundfiles]] directive
    hook(type => 'preprocess', id => 'soundfiles', call => \&preprocess);
    hook(type => 'format', id => 'soundfiles', call => \&format);
}

=pod

Upload to a subdir off the user's page.

=cut

# FIXME verify 'safe' 'rebuild'
sub getsetup () {
	return
		plugin => {
			safe => 1,
			rebuild => 0,
		},
		allowed_soundfiles => {
			type => "pagespec",
			example => "virusfree() and mimetype(audio/*) and maxsize(5MB)",
			description => "enhanced PageSpec specifying what sound files are allowed",
			link => "ikiwiki/PageSpec/attachment",
			safe => 1,
			rebuild => 0,
		},
                soundfiles_dir => {
			type => "string",
			default => [],
			description => "absolute path of the sound file repository",
			safe => 0,
			rebuild => 1,
		},
                soundfiles_url => {
			type => "string",
			default => [],
			description => "base url of the sound file repository",
			safe => 0,
			rebuild => 1,
                },
        # This is the same as the attachments plugin.
        # FIXME it is actually a global setting, see filecheck...
                virus_checker => {
			type => "string",
			example => "clamdscan -",
			description => "virus checker program (reads STDIN, returns nonzero if virus found)",
			safe => 0, # executed
			rebuild => 0,
		},
}


sub checkconfig () {
    if(! $config{rcs}) {
        error "The soundfiles plugin really needs an RCS.";
    }
    $config{cgi_disable_uploads} = 0;
}

=pod

    Store the soundfile metadata in %wikistate. Add pointers from the
    species and user pages to the relevant metadata in their
    %pagestate.

    This way we get a single copy of the metadata.

=cut
sub needsbuild (@) {
    my ($files) = @_;

    # use Data::Dumper;
    # warn "soundfiles::needsbuild start files: " . Data::Dumper::Dumper($files);

    if($config{rebuild}) {
        warn 'soundfiles: dropping metadata on the floor.';
        delete $wikistate{soundfiles};
    }

    # Populate %pagestate with the meta-data files that are scheduled
    # for re-rendering.
    # FIXME we could remove them from $files too.
    foreach my $metadata_filename (grep { /\.$metadata_ext$/ } @{$files}) {
        # warn " >> Found soundfile metadata file '$metadata_filename'";
        my $metadata = metadata_load(File::Spec->catdir($config{srcdir}, $metadata_filename));
        $metadata->{metadata_filename} = $metadata_filename;
        $wikistate{soundfiles}{metadata}{$metadata_filename} = $metadata;

        my $f = sub {
            my ($type, $species) = @_;
            my $page;

            if($type eq 'user') {
                $page = $metadata_filename;
                $page =~ s!/[^/]*\.$metadata_ext$!!;
            } else {
                $page = IkiWiki::Plugin::taxonomy::species_page($species->{genus}, $species->{species});
            }
            # warn "Adding data for '$type' page '$page'";

            $pagestate{$page}{soundfiles}{metadata}{$metadata_filename} = $type;

            # FIXME mdwn hardwired here.
            my $page_filename = $page . '.mdwn';

            # The species page may have been deleted.
            if(-e "$config{srcdir}/$page_filename") {
                # warn "soundfiles needsbuild: Adding dependency: $page -> $metadata_filename";
                add_depends($page, $metadata_filename);

                # FIXME here's hoping: add pages to $files and hope
                # that taxonomy::needsbuild picks up the species
                # files... This depends on the order ikiwiki processes
                # the same hook from different plugins.

                # FIXME a bit inefficient, but not to worry: the list
                # of files is probably short if we're not rebuilding.

                if(! $config{rebuild}) {
                    # Add each page once only.
                    push @{$files}, $page_filename unless grep { /^$page_filename$/ } @{$files};
                }
            } else {
                warn "soundfiles::needsbuild: file '$page_filename' does not exist.";
            }
        };

        &$f('user', $metadata_filename);
        map { &$f($background, $_); } @{$metadata->{bg_species}};
        map { &$f($foreground, $_); } @{$metadata->{fg_species}};
    }

    # use Data::Dumper;
    # warn "soundfiles::needsbuild end files: " . Data::Dumper::Dumper($files);

    return $files;
}

=pod

    Handle renaming of pages via the web interface.

    *** Note this doesn't handle renames via the git interface. FIXME
    the wiki must be entirely rebuilt for those. ***

    This hook gets called after all the basic sanity checks, so we
    should be able to assume that the rename will succeed.

FIXME consider renaming user pages. If $pagestate{src} has soundfile
metadata links...

FIXME can't rename KML files or soundfile metadata.

=cut
sub canrename {
    my %p = @_;
    # source and destination page names
    my $src = $p{src};
    my $dest = $p{dest};

    # Ignore the first check, before the renaming form is shown.
    return undef unless $dest;

    if($src =~ m!/species/!) {
        # FIXME should be stronger, same prefix as $src?
        if(!($dest =~ m!/species/!)) {
            return "'$src' is a page for a species, '$dest' is not.";
        }

        # Move the soundfile metadata across.
        $pagestate{$dest}{soundfiles} = $pagestate{$src}{soundfiles};

        foreach my $metadata_filename (keys %{$pagestate{$src}{soundfiles}{metadata}}) {
            my $metadata = $wikistate{soundfiles}{metadata}{$metadata_filename};
            die "soundfiles::canrename: Patching up '$metadata_filename', '$src' becomes '$dest'";
        }

        return '';
    }

    return undef;
}

=pod
    my $mime_subtype = upload_check($session, $dest, $file);

Verifies the proposed upload against the user-provided pagespec
in $config{allowed_soundfiles}.

Bombs with error on failure.
Returns the mimetype on success.
=cut
sub upload_check {
    my ($session,
        $dest, # where it's going to be put, under the srcdir
        $file  # the path to the attachment currently
        ) = @_;

    # Use a special pagespec to test that the sound file is valid.
    my $allowed;

    if (defined $config{allowed_soundfiles}
        && length $config{allowed_soundfiles}) {

        $allowed = pagespec_match($dest,
                                  $config{allowed_soundfiles},
                                  file => $file,
                                  user => $session->param('name'),
                                  ip => $session->remote_addr(),
            );

        if(! $allowed) {
            error(gettext("prohibited by allowed_soundfiles")." ($allowed)");
        }
    }

    # This actually lives in the filecheck plugin, urk.
    my $mimetype = IkiWiki::PageSpec::match_mimetype('FIXME', 'audio/*', file => $file);

    # FIXME this regexp is flimsy, depends on the success string of match_mimetype.
    $mimetype =~ m|audio/(.+)$|;
    return $1;
}

########################################
# Sound file uploads and edits.

sub sessioncgi {
    my ($cgi, $session) = @_;

    if($cgi->param('do') eq $upload_action) {
        show_upload_form($cgi, $session);
        exit;
    } elsif($cgi->param('do') eq $edit_action) {
        show_edit_form($cgi, $session);
        exit;
    }
}

sub show_edit_form {
    my ($q, $session) = @_;
    my $metadata_filename = $q->param('metadata_filename');
    my $metadata = metadata_load($metadata_filename);

    metadata_add_render_info('FIXME page', $metadata);

    my $p = { title => 'Edit sound file metadata',
              action => $edit_action,
              buttons => ['Save'],
              metadata_filename => $metadata_filename };

    show_form($q, $session, $p, $metadata);
}

sub show_upload_form {
    my ($q, $session) = @_;

    # Handle the case of no defaults.
    my $metadata = IkiWiki::userinfo_get($session->param('name'), $soundfiles_defaults);
    if($metadata) {
        metadata_add_render_info('FIXME page', $metadata);
    } else {
        $metadata = { recordist => $session->param('name') };
    }

    my $p = { title => 'Upload sound files',
              action => $upload_action,
              buttons => ['Upload sound files'] };

    show_form($q, $session, $p, $metadata);
}

sub show_form {
    my ($q, $session, $p, $metadata) = @_;
    my $user = $session->param('name');

    # FIXME this is isn't accurate, we don't want to edit this page.
    # The first arg is a putative page name.
    IkiWiki::check_canedit($user, $q, $session);

    my $form = CGI::FormBuilder->new(
        title => $p->{title},
        header => 0,
        method => 'POST',
        javascript => 1, # Generate JavaScript validation code
        messages => 'auto',

        params => $q,

        action => $config{cgiurl},
        template => { template('soundfilesupload.tmpl') },
       );

    my $javascript = '';
    my $lat = $metadata->{latitude};
    my $lng = $metadata->{longitude};
    my %js_args;

    $js_args{'draw_marker'} = 1;

    $javascript .= IkiWiki::Plugin::googlemaps::include_javascript(%js_args);

    $javascript .=
        '<script src="'.urlto('soundfilesupload.js', '', 1) # 1 -> absolute URL
      . '" type="text/javascript"></script>';

    $form->tmpl_param(javascript => $javascript);

    $form->field(name => 'do', type => 'hidden', value => $p->{action}, force => 1, required => 1);
    $form->field(name => 'sid', type => 'hidden', value => $session->id, force => 1);

    $form->field(name => 'date', type => 'text', label => 'Date (yyyy/mm/dd):', size => 10, validate => $date_re, required => 0);
    $form->field(name => 'time', type => 'text', label => 'Time (hh:mm):', size => 5, validate => $time_re, required => 0);
    $form->field(name => 'latitude', type => 'hidden', size => 12, validate => 'FLOAT', required => 0);
    $form->field(name => 'longitude', type => 'hidden', size => 12, validate => 'FLOAT', required => 0);
    $form->field(name => 'location', type => 'hidden', size => 100, required => 0);
    $form->field(name => 'elevation', type => 'text', size => 12, label => 'Elevation (m):', validate => '/^\d+m?$/', required => 0);
    $form->field(name => 'recordist', type => 'text', label => 'Recordist:', size => 40, required => 0);
    $form->field(name => 'recordingquality', type => 'select', label => 'Quality:', options => \@recording_quality, required => 0);
    # XHTML requires 'rows' and 'cols' but we really don't want to use that junk.
    $form->field(name => 'notes', type => 'textarea', validate => $notes_re, label => 'Notes:');
    my $rtd_label = 'Remember this data.';
    $form->field(name => 'setdefaults', options => [$rtd_label], value => $rtd_label);

    if($p->{action} eq $upload_action) {
        # This is mandatory but the multifile uploader breaks
        # FormBuilder's validation.
        #, required => 1);
        $form->field(name => 'soundfile', type => 'file', label => 'Add file:');
    } elsif($p->{action} eq $edit_action) {
        # Edit-specific behaviour.

        # Remember which file we're editing.
        $form->field(name => 'metadata_filename', type => 'hidden', value => $p->{metadata_filename});
        $form->tmpl_param(playsoundfile => $config{soundfiles_url} . '/' . $metadata->{file});
        if($metadata->{mp3}) {
            $form->tmpl_param(mp3 => $config{soundfiles_url} . '/' . $metadata->{mp3});
        }

        # Stash the RCS info.
        $form->field(name => 'rcsinfo',
                     type => 'hidden',
                     value => IkiWiki::rcs_prepedit($p->{metadata_filename}));

        # Arrange to redirect back to the original page.
        # This should be set by the CGI request.
        $form->field(name => 'page', type => 'hidden');
    }

    # Initialise the form fields using the given data.
    for my $f (keys %{$form->fields}) {
        if($metadata->{$f}) {
            $form->field(name => $f, value => $metadata->{$f});
        }
    }

    # Convert the HTML entities back in the notes field.
    $form->field(name => 'notes', value => decode_entities($metadata->{'notes'}));

    # Handle the species data specially.
    for my $species_field (qw/bg_species fg_species/) {
        $form->field(name => $species_field, type => 'hidden');
        # Initially selected species.
        $form->tmpl_param($species_field => $metadata->{$species_field})
            if defined $metadata->{$species_field};
    }

    IkiWiki::decode_form_utf8($form);
    IkiWiki::run_hooks(formbuilder_setup => sub {
        shift->(form => $form, cgi => $q, session => $session,
                buttons => $p->{buttons});
        });
    IkiWiki::decode_form_utf8($form);

    # On edit and upload only one form gets submitted.
    if($form->submitted && $form->validate) {
        my $field = $form->fields;

        IkiWiki::checksessionexpiry($q, $session, $field->{sid});

        # Only update the fields on the whitelist: the rest retain the
        # default (upload) or previous value (edit).
        for my $f (@metadata_field_whitelist) {
            if(defined $field->{$f} && $field->{$f} ne '') {
                $metadata->{$f} = $field->{$f};
            }
        }

        $metadata->{'fg_species'} = parse_species_list($field->{fg_species});
        $metadata->{'bg_species'} = parse_species_list($field->{bg_species});

        $metadata->{elevation} =~ s/m$// if $metadata->{elevation};

        # Retain as a default, if asked to.
        if($q->param('setdefaults')) {
            warn "Submission set userinfo.";
            IkiWiki::userinfo_set($user, $soundfiles_defaults, $metadata);
        }

        $metadata->{'user'} = $user;
        # Instead of scrubbing, encode the entities, etc. This is
        # probably closer to what the user expects. It drops newlines
        # though, and MarkDown does not work. Should be safe though.
        $metadata->{'notes'} = encode_entities($metadata->{'notes'});

        my $msg;
        if($p->{action} eq $upload_action) {
            # Handle the multiple-file upload.
            # FIXME probably should cope with the non-Javascript case
            # (having 'soundfile') too.
            warn "soundfiles: Processing uploaded files...";

            foreach my $param ($q->param) {
                next unless $param =~ /soundfile_(\d+)/;

                # Gotta use $q->param here; $field->() doesn't work
                # the magic of setting $q->tmpFileName().
                my $srcfile = $q->param($param);
                my $srcfile_tmp = $q->tmpFileName($srcfile);

                debug "  parameter: '$param' srcfile_tmp: '$srcfile_tmp'";

                # If no file is associated with this parameter, skip it.
                next unless $srcfile_tmp;

                my $metadata_canonical_filename = stash_uploaded_file($session, $metadata, $srcfile, $srcfile_tmp);
                $msg = "Uploaded soundfile '$srcfile' -> '$metadata_canonical_filename'";

                add_user_soundfile_directive($user, $metadata_canonical_filename);
            }
        } else {
            edit_uploaded_file($session, $form, $metadata);
            $msg = "Edited metadata of soundfile '$p->{metadata_filename}'";
        }

        IkiWiki::log_message(info => "'$user': $msg");

        # Scraped from editpage: Prevent deadlock with post-commit
        # hook by signaling to it that it should not try to do
        # anything.

        # FIXME Turns out rcs_commit_staged (at least for git) cannot
        # yield a conflict.
        my $conflict;
        IkiWiki::disable_commit_hook();
        $conflict = IkiWiki::rcs_commit_staged(
				message => $msg,
				session => $session,
            );

        IkiWiki::enable_commit_hook();
        IkiWiki::rcs_update();

        # FIXME update the wiki. From editpage.pm: Refresh even if
        # there was a conflict, since other changes may have been
        # committed while the post-commit hook was disabled.

        require IkiWiki::Render;
        IkiWiki::refresh();
        IkiWiki::saveindex();

    # FIXME patch up after an RCS conflict.
#     if(defined $conflict) {
#         $form->field(name => "rcsinfo", value => rcs_prepedit($file),
#                      force => 1);
#         $form->tmpl_param("message", template("editconflict.tmpl")->output);
#         $form->field("editcontent", value => $conflict, force => 1);
#         $form->field("do", "edit", force => 1);
#         $form->tmpl_param("page_select", 0);
#         $form->field(name => "page", type => 'hidden');
#         $form->field(name => "type", type => 'hidden');
# 			$form->title(sprintf(gettext("editing %s"), $page));
#         showform($form, \@buttons, $session, $q,
#                  forcebaseurl => $baseurl);
#     } else {
#         # The trailing question mark tries to avoid broken
#         # caches and get the most recent version of the page.
#         redirect($q, urlto($page, undef, 1)."?updated");
#     }

        # The trailing question mark tries to avoid broken
        # caches and get the most recent version of the page.
        if($p->{action} eq $upload_action) {
            # Upload: the user page is always safe.
            IkiWiki::redirect($q, urlto($user, undef, 1) . '?updated');
        } elsif($p->{action} eq $edit_action) {
            # Edit: The CGI request should have set 'page'.
            IkiWiki::redirect($q, urlto($form->field('page'), undef, 1) . '?updated');
        }
    } else {
        IkiWiki::showform($form, $p->{buttons}, $session, $q);
    }
}

=pod
    showform($form, $buttons, $session, $q);

Render the form, a variation of IkiWiki::showform in CGI.pm.

Note we invoke the formbuilder hook.

=cut

sub showform {
    my ($form, $buttons, $session, $q) = @_;

    if(exists $IkiWiki::hooks{formbuilder}) {
        IkiWiki::run_hooks(formbuilder => sub {
            shift->(form => $form, cgi => $q, session => $session,
                    buttons => $buttons);
                  });
    }

    my $template = $form->template;
    $form->tmpl_param(
#        indexlink => IkiWiki::indexlink(),
        wikiname => $config{wikiname},
        baseurl => IkiWiki::baseurl(),
	);

    IkiWiki::printheader($session);
    print $form->render(submit => $buttons);
}

=pod
    my $metadata_canonical_filename
      = stash_uploaded_file($session, $metadata, $srcfile, $srcfile_tmp);

Copy a file into the sound file repository, and create the metadata
and links for it. Stash the metadata into the RCS and rebuild the
wiki.

=cut
sub stash_uploaded_file {
    my ($session, $metadata, $srcfile, $srcfile_tmp) = @_;
    my $destdir = $config{soundfiles_dir};
    my $user = $session->param('name');

    # Provide a minimally informative filename for the sound file.
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;

    $year += '1900';
    $mon++;

    my $destfile = sprintf('%s_%4d-%02d-%02d',$user, $year, $mon, $mday);

    # Check the soundfile meets the user-given checks.
    # FIXME $destfile is a hack, it should be the final
    # metadata filename.
    my $mime_subtype = upload_check($session, $destfile, $srcfile_tmp);
    my $soundfile_ext = $audio_file_exts{$mime_subtype};

    if(! $mime_subtype || ! $soundfile_ext) {
        error("Unknown audio MIME subtype ($mime_subtype) for '$srcfile'.");
    }

    warn("Copying '$srcfile' -> '$destdir' / '$destfile' . '$soundfile_ext'.");

    # HStore will ensure $destfile is unique by adding a number to it.
    # FIXME why can't we move the CGI file?
    # http://search.cpan.org/~lds/CGI.pm-3.48/lib/CGI.pm#PROCESSING_A_FILE_UPLOAD_FIELD
    my ($storepath, $destfile_final) = hstore_copy($srcfile, $destdir, $destfile, $soundfile_ext);

    warn("HStore'd at '$storepath' / '$destfile_final'");

    # Update the metadata, reverse links.
    $metadata->{file} = File::Spec->catfile($storepath, $destfile_final);
    my $metadata_filename_only = $destfile_final . '.' . $metadata_ext;
    my $metadata_filename = File::Spec->catfile($session->param('name'), $metadata_filename_only);
    my $metadata_canonical_filename = File::Spec->catfile($config{srcdir}, $metadata_filename);

    # Get the length of the audio.
    # soxi is sensitive to filename extension, urk.
    # FIXME what happens if SOX doesn't work?
    my $sox_filename = File::Spec->catdir($destdir, $metadata->{file});
    # warn "SOX running '$sox_filename'";
    my $duration = `/usr/bin/soxi -D '$sox_filename'`
        or error "soxi choked on '$sox_filename'";

    $metadata->{duration} = sprintf("%.1f", $duration);

    # If the file is not an MP3, convert it to one so the Flash player
    # can handle it.
    # Debian's sox doesn't include mp3 write support, so lean on lame.
    if(!($soundfile_ext eq 'mp3')) {
        # Target
        my $mp3 = $sox_filename;
        $mp3 =~ s/\.$soundfile_ext$/.mp3/;

        `/usr/bin/sox $sox_filename -t wav - | lame - $mp3 && echo succeeded.`
            or error "Choked while converting '$sox_filename' to '$mp3'.";

        my $mp3f = $metadata->{file};
        $mp3f =~ s/\.($soundfile_ext)$/.mp3/;
        $metadata->{mp3} = $mp3f;
    }

    # Add metadata, place in the RCS staging area.
    metadata_write($metadata_filename, $metadata);

    return $metadata_canonical_filename;
}

=pod

edit_uploaded_file($session, $form, $metadata);

Update the persistent metadata for a sound file, preserving the
information created by stash_uploaded_file.

Mildly secure: $metadata->{metadata_filename} could be forged, but
then it would only update a JSON file within $config{srcdir}.

=cut

sub edit_uploaded_file {
    my ($session, $form, $metadata) = @_;

    my $metadata_filename = $form->param('metadata_filename');
    my $metadata_canonical_filename = File::Spec->catdir($config{srcdir}, $metadata_filename);

    # Ensure the putative full metadata filename is under
    # $config{srcdir}.
    # FIXME probably not symlink friendly.
    my $abs_file_path = abs_path($metadata_canonical_filename);
    if(! $abs_file_path =~ m|^$config{srcdir}/|) {
        error "edit_uploaded_file: metadata filename is fishy: 'metadata_filename'.";
    }

    # There must already be a file in JSON format too.
    my $metadata_old = metadata_load($metadata_filename);

    # ... and let's not be too paranoid.

    # Preserve the filename of the sound file, duration.
    # FIXME we want to retain all data the upload process created.
    $metadata->{file} = $metadata_old->{file};
    $metadata->{duration} = $metadata_old->{duration};

    # Update the metadata on disc.
    metadata_write($metadata_filename, $metadata);
}

=pod
    my $metadata = metadata_load($metadata_filename);

Populate the hashref $metadata from the JSON data stored in the file
named by $metadata_filename.

=cut

sub metadata_load {
    my ($metadata_filename) = @_;

    open my $metadata_fh, '<', $metadata_filename or error "Can't open '$metadata_filename'.";
    my $metadata_serialised = do { local( $/ ) ; <$metadata_fh> };
    close $metadata_fh;

    debug "metadata_load: $metadata_filename -> '$metadata_serialised'";

    my $metadata = JSON::from_json($metadata_serialised);

    return $metadata;
}

=pod
    metadata_add_render_info($metadata);

Add descriptions (common names) to the foreground and background
species lists in a metadata hashref, and add links to various
things. This info is easily derived from what is stored on disk and in
%wikistate.

FIXME a cache might make sense if there's anything expensive being
done here.

=cut
sub metadata_add_render_info {
    my ($page, $metadata) = @_;

    $metadata->{PLAYURL} = $config{soundfiles_url} . '/' . $metadata->{file};
    if($metadata->{mp3}) {
        $metadata->{MP3URL} = $config{soundfiles_url} . '/' . $metadata->{mp3};
    }

    $metadata->{USERURL} = urlto($metadata->{user}, '', 1);

    $metadata->{EDITURL} = IkiWiki::cgiurl(do => $edit_action,
                                           page => $page,
                                           metadata_filename => $metadata->{metadata_filename});
}

=pod
    metadata_write($metadata_dir_file, $metadata);

Store the hashref $metadata in JSON format into the file named by
$metadata_filename.

=cut

sub metadata_write {
    my ($metadata_filename, $metadata) = @_;
    my $metadata_serialised = JSON::to_json($metadata) . "\n";

    warn("Writing metadata to '" . $config{srcdir} . "' / '$metadata_filename'\n$metadata_serialised");
    IkiWiki::writefile($metadata_filename, $config{srcdir}, $metadata_serialised);
    IkiWiki::rcs_add($metadata_filename);
}

=pod
    add_user_soundfile_directive($user, $metadata_canonical_filename);

If the user doesn't have a page yet, create one and put a directive in
it that will list their sound files.

Also note that the user's page depends on the metadata.

FIXME probably want to do this irrespective of whether they have one
or not.

FIXME use the ikiwiki machinery here. Add the file to the RCS.

=cut

sub add_user_soundfile_directive {
    my ($user, $metadata_canonical_filename) = @_;
    my $user_page = user_file($user);
    my $user_filename = $user_page . '.mdwn';
    my $user_filename_canonical = $config{srcdir} . '/' . $user_filename;

    warn "add_user_soundfile_directive: '$user' '$user_filename_canonical'";

    # FIXME robustify
    if(!-e $user_filename_canonical) {
        warn "add_user_soundfile_directive: creating page '$user_filename'";

        my $tmpl = template("soundfiles_user.tmpl", blind_cache => 1);
        IkiWiki::writefile($user_filename, $config{srcdir}, $tmpl->output);
        IkiWiki::rcs_add($user_filename);
    }

    # FIXME assume the user has a soundfiles directive.
    # FIXME could use a pagespec here rather than individual files.
    warn "add_user_soundfile_directive: Adding dependency: $user_page -> $metadata_canonical_filename";
    add_depends($user_page, $metadata_canonical_filename);
}

=pod
    my $species_list = parse_species_list($string);

Convert a comma-sep list of the form 'genus species,...' into an array
of hashes.

=cut

sub parse_species_list {
    my ($str) = @_;
    my @gs;

    while($str =~ /(\w+) (\w+)(,|$)/g) {
        push @gs, {genus => $1, species => $2};
    }

    return \@gs;
}

########################################
# Soundfile storage

sub hstore_copy { hstore__add('copy', @_); }
sub hstore_move { hstore__add('move', @_); }

=pod
FIXME Returns (storage directory relative to $destdir, final filename).
FIXME this is overkill, as ikiwiki has a global lock.
=cut
sub hstore__add {
    my ($copy_or_move, $srcfile, $destdir, $destfile, $destext) = @_;

    $copy_or_move eq 'copy' or $copy_or_move eq 'move'
	or error "hstore__add('copy', ...) or hstore__add('move', ...)";
    $srcfile  or error "hstore__add() requires a source filename.";
    $destdir  or error "hstore__add() requires a destination directory.";
    $destfile or error "hstore__add() requires a destination filename.";

    my $hash = sha384_hex($destfile);
    my @subdir;

    # FIXME hardwire it to 1 level, perhaps generalise later.
    for(my $i = 1; $i > 0; $i--) {
        push @subdir, substr($hash, 2 * $i, 2);
    }

    my $storepath = File::Spec->catdir($destdir, @subdir);

    warn("hstore_add storepath: '$storepath'");

    ensure_dirhier($storepath);

    # FIXME do we really need the .lck files?
    # Deal with collisions:
    #   on failure to get lock or existence of file, uniquify $filename and try again
    #   otherwise copy/move, delete lock.
    my $uniquifier = 0;

    while(1) {
        # FIXME format the uniqufier to 000.
        my $target_file =
            ($uniquifier == 0 ? $destfile : ($destfile . '_' . $uniquifier)) . '.' . $destext;
        my $dest = File::Spec->catfile($storepath, $target_file);
        my $lock = $dest . '.lck';

	warn("hstore_add lock: '$lock'");

	# Signal intention to write to $dest
	# FIXME is this NFS proof?
        if(sysopen(LCK, $lock, O_WRONLY | O_CREAT | O_EXCL)) {
	    warn("hstore_add opened lock file");

	    if(flock(LCK, LOCK_EX | LOCK_NB) && (! -e $dest)) {

		warn("hstore_add flocked lock file");

		if($copy_or_move eq 'move') {
		    warn("hstore_add pre move");
		    File::Copy::move($srcfile, $dest) or error "Unable to move '$srcfile' to '$dest'.";
		    warn("hstore_add post move");
		} elsif($copy_or_move eq 'copy') {
		    warn("hstore_add pre copy");
		    File::Copy::copy($srcfile, $dest) or error "Unable to copy '$srcfile' to '$dest'.";
		    warn("hstore_add post copy");
		}

		close(LCK);
		unlink $lock;

		return (File::Spec->catdir(@subdir), $target_file);
	    }

	    warn("failed to flock lock file");

	    close(LCK);
	    unlink $lock;
        }

        $uniquifier++;
    }
}

=pod
FIXME soft-delete a file.
=cut
sub remove {
    my ($path, $filename) = @_;

    # FIXME we just soft-delete files for now.
    my $dest = File::Spec->catfile($path, $filename);
    chmod 0000, $dest;
}

=pod

    ensure_dirhier($path);

Ensure the given directory hierarchy exists.

FIXME this may be racy but we really shouldn't care.

=cut
sub ensure_dirhier {
    my ($path) = @_;

    if ( ! -d $path ) {
        File::Path::mkpath($path, { verbose => 0, mode => 0755 })
            or error "Unable to create '$path'.";
    }
}

########################################
# The preprocessor directive [[!soundfiles]]

sub preprocess {
    my %p = @_;
    my $page = $p{page};

    my $tmpl = template_depends("soundfiles.tmpl", $page, blind_cache => 1);

    # Uploading is independent of the page we're rendering.
    $tmpl->param(upload_action => IkiWiki::cgiurl());
    $tmpl->param(upload_do => $upload_action);

    return $tmpl->output;
}

sub format {
    my %p = @_;

    # Add the javascript at the end of the file (best practice).
    if (!($p{content} =~ s!(</body>)!include_javascript(%p).$1!em)) {
        # no </body> tag, probably in preview mode
        $p{content} .= include_javascript();
    }

    return $p{content};
}

sub include_javascript {
    my %p = @_;
    my $page = $p{page};
    my $js;

    $js = "<!--soundfiles.pm-->\n".soundfiles_js($page);
    $js .=
        '<script type="text/javascript" src="http://yui.yahooapis.com/combo?2.8.1/build/yahoo-dom-event/yahoo-dom-event.js&amp;2.8.1/build/element/element-min.js&amp;2.8.1/build/paginator/paginator-min.js&amp;2.8.1/build/datasource/datasource-min.js&amp;2.8.1/build/datatable/datatable-min.js"></script>'
      . '<script src="' . urlto(IkiWiki::Plugin::taxonomy::description_filename(), '', 1)
                        . '" type="text/javascript"></script>'
      . '<script type="text/javascript">var soundfiles_ikiwiki_baseurl="' . $config{url} . '/";</script>'
      . '<script src="' . urlto('soundfiles.js', '', 1) # 1 -> absolute URL
                        . '" type="text/javascript"></script>'
      . '<script type="text/javascript">var one_bit_url = "'. urlto('1bit.swf', '', 1) . '";</script>'
      . '<script src="' . urlto('1bit.js', '', 1) # 1 -> absolute URL
                        . '" type="text/javascript"></script>';

    return $js;
}

=pod

FIXME Generate the javascript for the soundfiles for the taxonomy,
species and user pages.

=cut
my %soundfiles_memo;

sub soundfiles_js {
    my ($page) = @_;

    if($page =~ m!/species/!) {
        return soundfiles_js_for_page(type => 'species',
                                      page => $page,
                                      soundfiles => $pagestate{$page}{soundfiles}{metadata});
    } elsif($page =~ m!/taxonomy!) {
        # Propagate the soundfile information upwards.
        my $node_fn = sub {
            my %p = @_;
            my %sfs;

            # Combine the children's hashes. Don't care about the elements.
            map { my %newHash = (%sfs, %{$_}); %sfs = %newHash; } @{$p{children}};

            return \%sfs;
        };

        my $species_fn = sub {
            my %p = @_;
            my $page = IkiWiki::Plugin::taxonomy::species_page($p{genus}, $p{species});

            return $pagestate{$page}{soundfiles}{metadata} || {};
        };

        # Populate the memo table.
        IkiWiki::Plugin::taxonomy::traverse_taxonomy_tree($page, $species_fn, $node_fn, \%soundfiles_memo);

        #use Data::Dumper;
        #warn "soundfiles_js / memo '$page': " . Data::Dumper::Dumper($soundfiles_memo{$page});

        return soundfiles_js_for_page(type => 'taxa',
                                      page => $page,
                                      soundfiles => $soundfiles_memo{$page});
    } else {
        # User pages.
        my $soundfiles = $pagestate{$page}{soundfiles}{metadata};

        # use Data::Dumper;
        # warn "soundfiles_js user page '$page' " . Data::Dumper::Dumper($pagestate{$page}{soundfiles});

        if($soundfiles) {
            return soundfiles_js_for_page(type => 'user',
                                          page => $page,
                                          soundfiles => $soundfiles);
        } else {
            return '';
        }
    }
}

sub soundfiles_js_for_page {
    my %p = @_;
    my $type = $p{type};
    my $js;

    # Punt the ordering to the display layer (Javascript).
    if($type eq 'user' || $type eq 'taxa') {
        my @markers;

        foreach my $metadata_filename (keys %{$p{soundfiles}}) {
            my $metadata = $wikistate{soundfiles}{metadata}{$metadata_filename};
            metadata_add_render_info($p{page}, $metadata);
            push @markers, $metadata;
        }

        # use Data::Dumper;
        # warn "soundfiles_js_for_page($p{page}): " . Data::Dumper::Dumper(\@markers);

        $js = 'var user_recordings = [' . join(',', map { JSON::to_json($_); } @markers) . '];';
    } else {
        my @fg_markers;
        my @bg_markers;

        #use Data::Dumper;
        #warn "soundfiles_js_for_page($p{page}): " . Data::Dumper::Dumper($p{soundfiles});

        foreach my $metadata_filename (keys %{$p{soundfiles}}) {
            my $metadata = $wikistate{soundfiles}{metadata}{$metadata_filename};

            metadata_add_render_info($p{page}, $metadata);

            if($p{soundfiles}->{$metadata_filename} eq $foreground) {
                push @fg_markers, $metadata;
            } elsif($p{soundfiles}->{$metadata_filename} eq $background) {
                push @bg_markers, $metadata;
            } else {
                warn "FIXME '$metadata_filename' is not a FG or BG recording for page '$p{page}'.";
            }
        }

        $js = 'var bg_recordings = [' . join(',', map { JSON::to_json($_); } @bg_markers) . '];'
            . ' var fg_recordings = [' . join(',', map { JSON::to_json($_); } @fg_markers) . '];';
    }

    return '<script type="text/javascript">' . $js . '</script>';
}

=pod

    my $soundfiles_count = count_soundfiles($genus, $species);

Counts the number of soundfiles (foreground and background) for the
given species.

=cut
sub count_soundfiles {
    my ($genus, $species) = @_;
    my $page = IkiWiki::Plugin::taxonomy::species_page($genus, $species);
    my $bg = 0;
    my $fg = 0;

    foreach my $type (values %{$pagestate{$page}{soundfiles}{metadata}}) {
        if($type eq $foreground) {
            $fg++;
        } elsif($type eq $background) {
            $bg++;
        } else {
            warn "Metadata neither bg or fg for page '$page'";
        }
    }

    return [$bg, $fg];
}

1;
