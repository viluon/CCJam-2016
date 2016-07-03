# Gravity Girl

[![forthebadge](http://forthebadge.com/images/badges/designed-in-ms-paint.svg)](http://forthebadge.com)
[![forthebadge](http://forthebadge.com/images/badges/gluten-free.svg)](http://forthebadge.com)
[![forthebadge](http://forthebadge.com/images/badges/powered-by-electricity.svg)](http://forthebadge.com)

A [Gravity Guy](http://www.miniclip.com/games/gravity-guy/en/) clone by @viluon, an entry for [CCJam 2016](http://www.computercraft.info/forums2/index.php?/topic/26906-ccjam-2016-has-begun/).

## Preface
I joined CCJam because of two reasons. First, I haven't attended a similar competition before, and second, because I believed (and still believe) that there is a shortage of great ComputerCraft games. Multiplayer is one of the most crucial features of Minecraft, and in extension, of [ComputerCraft](http://www.computercraft.info/) as well, but there is just a handful of decent games for CC, and very very few of them (if any) have multiplayer. The capabilities of ComputerCraft devices are well beyond those of early personal computers from the last century, and yet *somehow* the latter beats the former as a gaming platform. We, ComputerCraft players, need to fix this. We need more multiplayer games. We need more "wow" games (this is easier than ever with the new teletext characters). We need more games that are actually fun, and not just "this must have been hard to implement".

Gravity Girl was born as a result of that need (and I thought it'd make a good entry for CCJam). Using the [BLittle API](http://www.computercraft.info/forums2/index.php?/topic/25354-cc-176-blittle-api/) by Bomb Bloke to enhance resolution, [bump.lua](https://github.com/kikito/bump.lua) by @kikito for bulletproof collision detection, and [Gravity Guy](http://www.miniclip.com/games/gravity-guy/en/focus/), a title loved by casual gamers as its template, it is the choice number \#1 whenever you want to challenge your fellow ComputerCrafters, or just kill time while your turtle makes its way back to the surface.

## A Word of Warning
Given the limited time for CCJam, I was not able to test everything everywhere. There is still a lot to do, fix, and improve. In other words, Gravity Girl is still very much a work in progress. What matters the most, however, is that the UI was only tested on computers. That is, I didn't try running it on a monitor, turtle, or a PDA. Since pretty much everything counts with `term.getSize()`, it should all scale *up* rather well, but the opposite might not be true.

## Installation
The easiest way to get Gravity Girl currently is to use @apemanzilla's `gitget`, with this command:

```bash
pastebin run W5ZkVYSi viluon CCJam-2016
```

And then run the game with the `r` script.
