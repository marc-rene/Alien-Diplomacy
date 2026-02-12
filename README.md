
# Autonomous Agents CA Idea writeup

#### Eduard and César

## Summary

Starting off, the player can walk around a Solar System in the Galaxy, walking alongside
the planets and stars. An enemy mothership arrives and starts spawning a boid-based
storm of smaller attack-aircraft that are attacking your planets.

You as the player can see these boids flying around the planets, attacking them, and
then eventually fly back to the mothership to refuel, and then back out again to attack.

You as the player have 2 ways of proceeding.

### Attack back - fire-with-fire, boids-with-boids

You can then spawn your own mothership which can create boids of your own to shoot
down the attacker’s boids and eventually the mothership. Watching the battle rage on
and hope you have enough boids to win the fight.

### Diplomacy – Talk One-on-One

The Alien commander is open to talks. You can talk with the commander via hologram,
and using LLM, the commander can either be:

 - Convinced to stand down (Good ending)
 - Nuke himself which then destroys all surrounding planets (Bad ending)
 - Annoy him and watch him spawn more boids to attack (Higher diƯiculty)


## What will be needed

### Enemy Commander

#### Speech and response

The enemy commander will be able to be contacted at any point during the demo. When
talking to him, the player will use the microphone built-in to the Meta Quest 3s to record
their speech.

The recorded speech will then go through Speech-to-text. This text will then go through
a local LLM *(or API call to an external one if RAM is too low)* for a unique response and
whether the given speech was:

 - Diplomatic *(calm-down the commander, move closer to good ending)*
 - Aggressive / Threatening *(Antagonise the commander, move closer to bad / nuclear option)*
 - Jokey / demeaning / Silly *(Annoy the commander and cause more boids to spawn, or make current enemy boids more aggressive)*

Whatever speech type was given will contribute to a hidden score to determine what
ending to give. The commanders’ response will be generated in text form and sent back
to the user. An audio feedback in “Alien language” *(Pseudo-Random noise)* will be
generated and it’s duration will be based on the length of the text response. The text will
be the “Subtitles” for the commanders response.

#### Mesh

The command is an alien and can be contacted via hologram, so we’ll be going for a
**“Davey-Jones looking individual”**. Animated tentacles and particle eƯects will be added.


### Boids

#### Enemy

Enemy boids will have planets as their target.

They’ll first choose a point away from the planet and move there.

Then they’ll approach the planet so that they have a straight line of fire at the planet and
can perform a Strafing-Run attack.

Any Friendly boids that are encountered directly in-front of them will be shot and have
damage be applied to them.

When enemy boids have run out of ammo, their target will change to the mother ship so
that they can go back, slow down and refuel, and then head back to the targeted planet.

#### Friendly

Friendly boids will have the planets as their targets but will constantly over-shoot and
loop back around, thus circling around the planets.

Any enemy boids directly in front of friendly boids will also be shot and have damage
applied to them.

#### Reminder to make this fully work on your own device
The LLM Models need to downloaded locally and so does the NobodyWhoAsset libary
Links to download the essentials that are used to make the LLM work.

https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/blob/main/gemma-2-2b-it-Q4_K_M.gguf
https://huggingface.co/alela32/USER-bge-m3-Q8_0-GGUF/blob/main/user-bge-m3-q8_0.gguf

