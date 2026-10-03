class_name Build
extends RefCounted
## What this build is allowed to show. Debug, Limited, or Release.
##
## ---------------------------------------------------------------------------
## WHERE THE ANSWER COMES FROM
## ---------------------------------------------------------------------------
## An export preset's `custom_features`, read through OS.has_feature(), wins.
## DEFAULT below is only the fallback for when no tag is present -- which in
## practice means the editor.
##
## Feature tags rather than a bare constant, because the threat here is
## forgetting: a constant has to be flipped by hand before every export and put
## back afterwards, and the failure mode is shipping a build with every
## developer tool in it. A tag lives in the preset, so each export carries its
## own answer and "which build is this" is never a thing anyone remembers.
##
## To test another mode from the editor, change DEFAULT. An exported build
## ignores it.
##
## ---------------------------------------------------------------------------
## LIMITED VS RELEASE
## ---------------------------------------------------------------------------
## Today they allow the same things -- no debug tooling at all -- and differ
## only in the title screen's designation line. Limited is the playtest build;
## it exists as its own mode so a playtest-only allowance can be added later in
## one of the questions below without touching any call site.

enum Mode { DEBUG, LIMITED, RELEASE }

## The mode used when no export preset says otherwise -- i.e. running from the
## editor. Change this to sit in Limited or Release while developing.
const DEFAULT: Mode = Mode.DEBUG

## Feature tag per mode. Set one of these in a preset's `custom_features`.
## Without TAG_DEBUG an export could not BE Debug: no tag falls back to DEFAULT,
## which is whatever the editor happens to be sitting in.
const TAG_DEBUG := "build_debug"
const TAG_LIMITED := "build_limited"
const TAG_RELEASE := "build_release"

static var _resolved: int = -1

## This build's mode. Resolved once: feature tags cannot change at runtime.
## Most restrictive tag first, so a preset carrying two by mistake ships with
## less tooling, never more.
static func mode() -> int:
	if _resolved < 0:
		if OS.has_feature(TAG_RELEASE):
			_resolved = Mode.RELEASE
		elif OS.has_feature(TAG_LIMITED):
			_resolved = Mode.LIMITED
		elif OS.has_feature(TAG_DEBUG):
			_resolved = Mode.DEBUG
		else:
			_resolved = DEFAULT
	return _resolved

static func name_of(m: int) -> String:
	match m:
		Mode.LIMITED: return "Limited"
		Mode.RELEASE: return "Release"
	return "Debug"

## The title screen's line under the subtitle, so anyone holding the device (or
## a screenshot of it) can tell which build they are looking at. Arcade-cabinet
## terms: service mode is the operator's hidden test menu, a location test is
## an unreleased cabinet put in a few arcades to watch real players, and
## "insert coin" is the shipped machine waiting for one.
static func designation_of(m: int) -> String:
	match m:
		Mode.LIMITED: return "LOCATION TEST // LIMITED BUILD"
		Mode.RELEASE: return "INSERT COIN // RELEASE BUILD"
	return "SERVICE MODE // DEBUG BUILD"

## The game's version, e.g. "1.0.0". project.godot's application/config/version
## is the one place it is set; the title screen's corner watermark and the
## Windows exports' file/product version both read it from there.
static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))

# --- What each mode allows --------------------------------------------------
# Named for the QUESTION each answers, not for the mode. A call site asking
# "is this a debug build" ends up re-deciding policy at every call site, and the
# answers drift; asking "may I show the asset viewer" keeps the policy here.

## The developer-only screens on the title screen: Asset Viewer and the Game
## States stub. DEBUG only -- these are whole tools, not conveniences.
static func shows_dev_screens() -> bool:
	return mode() == Mode.DEBUG

## The pause menu's Debug Menu page, and with it everything the `Debug`
## autoload can switch on: debug mode's input shortcuts and overlay,
## invincibility, grid retuning. DEBUG only; `Debug` itself refuses to turn on
## otherwise, so no other route can reach them either.
static func shows_debug_panel() -> bool:
	return mode() == Mode.DEBUG
