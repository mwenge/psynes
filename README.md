# Psychedelia by Jeff Minter (NES)

<img src="https://user-images.githubusercontent.com/58846/114322575-e3e6b480-9b18-11eb-8371-2cbcb760330b.gif" height=300>


<!-- vim-markdown-toc GFM -->

* [Play](#play)
* [Controls](#controls)
* [Build](#build)
* [About](#about)

<!-- vim-markdown-toc -->
Jeff Minter never ported his game [Psychedelia] to the Nintendo Entertainment system. So I did.


## Play
On Ubuntu you can install [FCEUX], the NES emulator, as follows:
```
sudo apt install fceux
```

Once you have that installed, you can [download the game]() and play it.

##Controls
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
Made out of curiosity as part of the [Psychedelia][https://github.com/mwenge/psychedelia] project.

[cc65]: https://cc65.github.io/
[FCEUX]: https://fceux.com/
[llamaSource]: https://en.wikipedia.org/wiki/Trip-a-Tron
[Neon]: https://en.wikipedia.org/wiki/Neon_(light_synthesizer)
[first realized concept]: http://www.minotaurproject.co.uk/psychedelia.php
[Psychedelia]: https://en.wikipedia.org/wiki/Psychedelia_(light_synthesizer)
[atari800]: https://atari800.github.io/
[hatari]: https://hatari.tuxfamily.org/download.html
