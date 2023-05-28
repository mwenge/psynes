# Psychedelia by Jeff Minter (NES)
<img src="https://github.com/mwenge/psynes/assets/58846/d6dc378f-137c-41eb-bdd7-f9ccb2ab0887" height=400>

Jeff Minter never ported his game [Psychedelia] to the Nintendo Entertainment system. So I did. Maybe I don't know what I'm doing.

<!-- vim-markdown-toc GFM -->

* [Play Online](#play-online)
* [Play](#play)
  * [Controls](#controls)
* [Build](#build)
* [About](#about)

<!-- vim-markdown-toc -->

## Play Online
You can play it [online here](https://mwenge.github.io/psynes).

## Play
On Ubuntu you can install [FCEUX], the NES emulator, as follows:
```
sudo apt install fceux
```

Once you have that installed, you can [download the game](https://github.com/mwenge/psynes/raw/master/bin/psychedelia.nes) and play it:

```
fceux psychedelia.nes
```

### Controls
You have less fine-grained control than on the C64 version as this version uses the gamepad only. Apart from
moving the cursor around and firing, the other buttons on your gamepad will cycle through the available
symmetries and preset patterns. 

## Build
On Ubuntu you can install the build dependencies as follows:
```
sudo apt install cc65 fceux python3
```

Then you can compile and run:

```sh
$ make
```

## About
Made out of curiosity as part of the [Psychedelia](https://github.com/mwenge/psychedelia) project.
This [example project](https://github.com/bbbradsmith/NES-ca65-example/) was a big help in getting started.
Let's face it: it's slow. I'm still thinking of what I can do about that.


[cc65]: https://cc65.github.io/
[FCEUX]: https://fceux.com/
[llamaSource]: https://en.wikipedia.org/wiki/Trip-a-Tron
[Neon]: https://en.wikipedia.org/wiki/Neon_(light_synthesizer)
[first realized concept]: http://www.minotaurproject.co.uk/psychedelia.php
[Psychedelia]: https://en.wikipedia.org/wiki/Psychedelia_(light_synthesizer)
[atari800]: https://atari800.github.io/
[hatari]: https://hatari.tuxfamily.org/download.html
