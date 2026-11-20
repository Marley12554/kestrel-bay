# Kestrel Bay Godot project

Open `project.godot` in Godot 4.7.1. The main scene starts the harbor city. `main.tscn` is the smaller waterfront scene used for the original handling, window escape and marine collision tests. Both scenes share the player, lift, audio and encounter code.

The city runs with the Compatibility renderer. The web preset uses a single thread and all URLs are relative to the Pages project path. Native and browser progress use separate stores. See the [repository readme](../README.md) for controls and the build, bake and test commands.
