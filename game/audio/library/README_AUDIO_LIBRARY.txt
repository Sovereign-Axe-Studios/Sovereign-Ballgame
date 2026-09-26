BALLGAME AUDIO LIBRARY
======================
Made by Ballgame Sound Lab. 12 music tracks and 61 sound effects.

INSTALL
  Unzip so the "library" folder ends up inside res://audio
  (for the default that is game/audio/, giving res://audio/library/).
  Open the project in Godot and let it import. Then open the Asset Viewer, Audio tab.

LAYOUT
  library/music/menu/<name>/      menu music, one folder per tune
  library/music/game/<name>/      game music, one file per round tier (_tier1 to _tier5)
  library/sfx/<category>/<name>/  sound effects grouped by what they are for
  Variations are in the same folder as their original: _a_..., _b_..., _c_...
  *_intro files play once before the loop (only some menu tracks have one).
  audio_catalog.gd   what the game and Asset Viewer read (do not edit by hand)
  audio_manifest.json  the same data as JSON, for tools and the audio team

FORMATS
  WAV: 44100 Hz, 16 bit, stereo. Loop files carry a loop marker over the whole file.
  OGG Vorbis: quality 5, stereo. Much smaller. Set Loop on import for loop files if you use them directly.
  The game loads music from OGG when it exists and effects from WAV, and loops music itself.

GAME TIERS
  Game music is one file per round tier. All five tiers of a track have exactly the same length and
  bar structure, so the game can switch tiers at any moment without losing the beat.

REPLACING A SOUND
  Keep the same file name and folder and Godot re-imports it. Renaming a file needs a re-export so the catalog matches.
