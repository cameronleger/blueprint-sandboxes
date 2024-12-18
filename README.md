## Blueprint Sandboxes

Temporary Editor-lite permissions in Lab-like environments for designing and experimenting.

Inspired by previous mods such as [Edit-Blueprints](https://mods.factorio.com/mod/Edit-Blueprints) and [Blueprint Designer Lab](https://mods.factorio.com/mod/BlueprintLab_design), [this mod](https://mods.factorio.com/mod/blueprint-sandboxes) aims to handle the situations where you want to design or tweak some Blueprints in a God-mode-like way, but without saving your active game, loading a different sandbox game, then leaving that to go back to the original once done.

To that end, it supports personal and team Sandbox Surfaces which enable: God-mode, extra Recipes (and Technologies if you wish), and automated construction. Getting in and out of Sandboxes is immediate and toggle-able via shortcuts (defaults to Shift+B).

To teach you the basics and provide many more details, the in-game Tips-and-Tricks are used; the first is visible after a few seconds, and the rest after you start using the Sandbox. The rest of this is considered a non-exhaustive summary - if you want to know more, see those Tips/Tricks!

* Multiple Sandboxes: your own and one for your force/team.
* Blueprint Intput/Output: Copy/Paste, Blueprint Library, and in-Cursor.
* Item Input/Output: Infinity chests and loaders are available.
* God-mode: Fly around and construct/deconstruct much faster.
* Persistent Inventory: Your Inventory is saved and restored when exiting/entering.
* Automated Construction: Ghosts are automatically built for you.
* Surface Properties: Adjust gravity, pressure, etc. to mimic other Planets.
* All Recipes: If desired, use all Technology (instead of what you already know).
* Entity Generation: Place interesting entities like resources, trees, enemies, etc.
* Tile Placement: Place any kind of tiles wherever you want, or revert back to lab tiles.
* Default Equipment: You can decide what an empty Sandbox starts with.

# Known Issues / Frequently Asked Questions

### The Sandbox is not a Planet

Many Factorio 2.0 features, capabilities, definitions, mechanics, etc. are directly coupled to the concept of a Planet: a real, physical location that may be travelled to. Heating on Aquilo, lightning on Fulgora, and music are commonly known examples. Planets also carry other features that are not desirable for Sandboxes: appearing in all Planetary-selection menus, allowing travel with Platforms, and limiting recipes based on planetary conditions, to name a few. Lastly, Planets _must_ be known ahead of time, statically, while the game is loading its prototypes.

Sandboxes are meant to be quite different than that: ephemeral, dynamic, and personal. Each player has a Sandbox for themselves, and each Force/team does as well.

Sandboxes and Planets are not compatible. The only reasonable approach I can imagine right now is to have an additional, singular Planetary Sandbox that aims to generally set as many parameters as possible to be widely useful, and everyone would have access to it. This is totally fine for single-player, but it has very different implications for multi-player games.

### Music disappears while in Sandbox

This is an issue with Factorio's 2.0 music system (which only works for Planets and Platforms). See **The Sandbox is not a Planet**. There is a workaround that may solve this for you: there is a hidden setting in "the rest" (accessed by holding `ctrl` + `alt` while clicking "Settings" in the menu) called `ambient-music-based-on-physical-location`. If you cannot tell based on the name, this means that while you are in a Remote View (the default way of accessing the Sandbox), the music is still based on where your Character is. This naturally applies to the rest of the game as well, so it may not be to your taste.

### Cannot freeze due to cold, or place lightning collectors

This is again an issue with Factorio's 2.0 surface-specific settings (which only works for Planets and Platforms). See **The Sandbox is not a Planet**.

### Cannot Undo in (Real World/Sandbox) after coming from (Sandbox/Real World)

This is an issue with Factorio, and there's nothing this mod can do about it (while still being this mod).

### `on_pre_surface_cleared` in error message

When Resetting the Sandbox and the game crashes with any other mod listed in the error - it's _that_ mod's fault for not handling `on_pre_surface_cleared`.

### Crafting in Sandbox works towards Lazy Bastard

Crafting Counts cannot be segregated in the way that you want - this does not work for Lazy Bastard.

### Selecting new contents for some Blueprints will include Illusions instead of Real Entities

There is a significant flaw in Factorio's handling of Blueprints that have already been created when you want to "select new contents" for them; to quote a Factorio dev, it's "kind of a giant hack in my opinion and I don't see it getting re-worked any time soon." This is the only real acknowledgement of this issue, whereas all other responses seem to deflect or feign ignorance. As far as I have found, this is the only (and for our purposes, quite a large) shortcoming of the otherwise excellent Modding API.

In short, this mod has _no_ access or capability to adjust a Blueprint when you are "selecting new contents." This capability is necessary to swap our Fake Illusions (script-less Entities that replace other, more complicated ones for various reasons) with their Real Counterparts. This cannot be overcome without Factorio itself being fixed by the development team. That said, there is _potentially_ a hackish and unnecessary workaround when you do this to a Blueprint in your Inventory.

I have found at least three existing discussions on this topic, for reference:

* [New contents for blueprint broken vs. new blueprint](https://forums.factorio.com/viewtopic.php?f=29&t=88793)
* [Blueprints missing entity list when reused](https://forums.factorio.com/viewtopic.php?f=7&t=99323)
* [Updated blueprint has no entities during on_player_setup_blueprint](https://forums.factorio.com/viewtopic.php?f=48&t=88100)

### Blueprint Library sourced Blueprints will not transfer via Cursor

Similar to above, another Factorio bug describes Blueprints in your cursor that are sourced from the Blueprint Library will be described as __not__ `valid_for_read`, thus accessing their contents is not possible, so this mod cannot transfer them into your Sandbox cursor because of that.

I have found at least three existing discussions on this topic, for reference:

* [How to access temporary BP in player's hand?](https://test.forums.factorio.com/viewtopic.php?t=93956)
* [Updated blueprint has no entities during on_player_setup_blueprint](https://forums.factorio.com/viewtopic.php?f=48&t=88100)
* [get blueprint-book from library link](https://test.forums.factorio.com/viewtopic.php?t=95272)

### Editor Extensions Lab Setting is incompatible

When Editor Extensions is enabled, its Lab Setting is disabled because it is incompatible with this mod.

## Credits
* undermark5: Factorissimo Performance Improvements
* KirillNaumkin and dodther: Russian translations