


  

# Alien Diplomacy

![alt text](Godot/Art/Logo/T_AlienDiplomacySpash.svg "Alien Diplomacy Logo")

**VR space strategy meets AI diplomacy** — fight massive boid swarms or talk your way out. Built for **Godot 4.6** with **OpenXR** (Meta Quest 3S) and **local LLM** dialogue.

  

#### Eduard and César · Autonomous Agents CA

  

---

  

### Table of Contents

  

- [Summary](#summary)

- [Progress so far](#progress-so-far)

- [Future plans](#future-plans)

- [Getting started](#getting-started)

  

---

  

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

- Annoy him and watch him spawn more boids to attack (Higher difficulty)

  

---

  


### Highlights

  

-  **Up to ~210,000 boids** (so far) on PC and **~10,000 on Meta Quest 3S** (so far) via ECS + GPU instancing ([MultiMesh](https://docs.godotengine.org/en/stable/classes/class_multimeshinstance3d.html))

-  **Custom procedural planets** — Using noise textures (Perlin, Simplex, and Cellular) with threshold-based colours *(oceans, islands, mountains, gas giants, moons, etc...)*

-  **Local LLM diplomacy** — talk to the alien commander in-game with Gemma 2 and NobodyWho; Speech-to-Text planned for later

-  **Tunable performance** — configurable physics tick rate and optional TPAA *(Temporal Physics Anti-Aliasing)* or aka **"offbrand physics DLSS"** for smooth GPU instance Buffer updating.

-  **One-Click setup** — scripts download addons and GGUF models in parallel; no manual plugin or model installs

  

---

  

# Overview

  

## Boids

  

Boids in this project are rendered using an **ECS-style** layout and [MultiMeshInstance3D](https://docs.godotengine.org/en/stable/classes/class_multimeshinstance3d.html) for **GPU instancing**

That let's us reach **~220,000 boids** on an average PC and **~10,000** on the Meta Quest 3S. When combined with the LLM the boids are reduced down to 4,000 to keep acceptable performance.


Physics tick rate runs the buffer updating and an optional double-buffer mode ***("offbrand physics DLSS")*** are used so we get extra smoothness on MultiMesh3D updating.


![alt text](Assets/AA_SC_(2).png "Boids screenshot 1")
![alt text](Assets/AA_SC_(3).png "Boids screenshot 2")
![alt text](Assets/AA_SC_(4).png "Boids screenshot 3")
![alt text](Assets/AA_SC_(5).png "Boids screenshot 4")

All boids will target different planets and swarm them.

### Motherships
Both Friendlies and Enemies have a **Mothership** which our boids spawn from.
These motherships wander the solar system, using avoidance steering to avoid colliding into planets. 

#### Enemy Mothership

The enemy mothership will float to the border regions of the solar system, avoiding all of the planets and friendlys, keeping to the outside always.

![Enemy Mothership](Assets/ENEMY_SHIP.png "Enemy Mothership")

#### Friendly Mothership
The friendly mothership will always try to be close to the planets. It will steer to avoid the planets aswell but will make sure to stay close to the action!


![Friendly Mothership](Assets/FRIEND_SHIP.png "Friendly Mothership")

### Factions

Boids can all be part of different factions, via a `PackedByteArray`. All bytes are treated like a signed 8-bit integer, giving us a range from -127 to +128:

-  **0** means the Boid is inactive / destroyed

-  **1 -> 128** means the Boid is friendly, and they have anywhere from 1-127 units of health left

-  **-1 -> -127** means the boid is hostile, their health works the same way.

We can implement unique 2<sup>N</sup> factions using this logic

  

## Planets

  

Planets are rendered with a custom GDShader that samples a noise texture in stages.

First it will pick a point in the noise texture and see what threshold it lies in. Custom colours are then applied to that threshold, letting us do islands on oceans, then mountains on those islands, as all colouring is done from the input noise.

We used a combination of **Perlin**, **Simplex**, and **Cellular** noise to achieve different looks (e.g. Earth-like, Sun-like).

  

## LLM

  

We use the [NobodyWho](https://github.com/nobodywho-ooo/nobodywho) plugin so the in-game LLM runs locally. You can already have a text conversation with the model from the chat UI. We're working on **Speech-to-Text** so you can speak to the alien commander at runtime (e.g. via the Quest microphone) instead of typing.

  

  

## Easy Setup

  

Custom setup scripts mean you don’t have to manually download LLM models or Godot plugins:

  

-  **Windows:** run `Setup.bat` from the repo root.

-  **Linux / macOS:** run `Setup/Setup.py` with [Python 3](https://www.python.org/downloads/).

  

Downloads run **in parallel** (3 items at once), then files are copied into the right folders and temporary files are removed. A log is written to `Setup/Setup attempt.log`.

  
  

# Original Plans *(Febuary)*

  

## Enemy Commander

  

### LLM Speech and response

  

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

  

### Mesh

  

The command is an alien and can be contacted via hologram, so we’ll be going for a

**“Davey-Jones looking individual”**. Animated tentacles and particle effects will be added.

  
  
  

## Enemy

  

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


---


# Getting started

  

1.  **Clone the repo** using `git clone https://github.com/marc-rene/Alien-Diplomacy.git`

2. -  **Windows:** double-click `Setup.bat`.
	-  **Linux / macOS:**  Run the command `python3 Alien-Diplomacy/Setup/Setup.py`.

3. Once your headset is connected and ADB is running, run `Godot/copy_model.ps1` using an Administrator Terminal Session. This will copy the LLM model to the headset.

4.  Open the `project.godot` in **Godot**

  

The setup script downloads the two GGUF models and the NobodyWho addon into the right places. If you prefer to download manually, use:

  

- [gemma-2-2b-it-Q4_K_M.gguf](https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/blob/main/gemma-2-2b-it-Q4_K_M.gguf) → place in `Godot/`

- [user-bge-m3-q8_0.gguf](https://huggingface.co/alela32/USER-bge-m3-Q8_0-GGUF/blob/main/user-bge-m3-q8_0.gguf) → place in `Godot/`

- [NobodyWho Godot addon](https://github.com/nobodywho-ooo/nobodywho/releases) → extract into `Godot/addons/`


# What we learned
## Eduard
Working with a local LLM in Godot is an absolute pain. Godot VR taught me that GEMMA needs very deliberate prompting to work as intended. Overly complex conditional instructions are ignored or just cause issues. Having a more direct commanding prompt makes it respond more reliably.

The most time consuming part was getting the LLM to work on the Meta Quest 3S. File paths were an absolute mess to work with while also requiring ADB to push files to get everything working as intended. Also making sure the release build was used instead of the debug build would be the main reason if the APK would run on the headset. 

On top of that, getting the AI responses to actually trigger game events required building a token accumulation system from scratch, the response finished signal doesn't reliably carry the full text, so every token had to be caught and stored manually. Speech to text was originally the intended input method, making the diplomacy feel a lot more natural and immersive, but it had to be scrapped entirely.

Permissions on the Quest 3S turned out to be a nightmare, getting the correct permissions declared, granted at runtime and this was a rabbit hole that ate significant time with nothing to show for it, so a virtual keyboard was built instead. 
For the alien voice I used Godot's AudioStreamGenerator to push raw sine wave frames in real time during generation, modulating the frequency and wobble based on keyword detection in the response so the character actually sounds different when it's angry versus when it's accepting a deal,all without a single audio asset. 

Getting the chat UI into VR space meant routing signals through Godot's group system since a Viewport2Din3D sub viewport is isolated from the main scene tree, so a direct signal connection simply doesn't reach the boids.

## César

Using Multmeshes and adopting an ECS style approach was definetly different. 

Many of the workflows with other Boids couldn't be adopted 1-to-1 and had to be changed due to not having easy access to each boids position using the usual Godot workflow.

Making sure performance was solid enough to get up to 210,000 boids *(on desktop)*, and about 9,000 on the Meta Quest 3S, was also a BIG challenge.
Performance was a key factor and constantly tested and I learned how to properly use the Godot Profiler. 
Rather than having every boids next position and behaviour be calculated and pushed to the various multmesh buffers all on the render tick, which KILLED performance, we had to be smart.

### Getting Offbrand Physics DLSS *(Physics SwapChain)*
 - **First attempt** was to do everything on the physics tick instead. This helped somewhat but performance very quickly plummeted if we had too many boids. This is where I learned about the *[Physics Death Spiral](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-physics-common-max-physics-steps-per-frame)* where if the physics tick ever takes longer than the maximum time its allocated, it will try catch up with itself and the render thread suffers and performance plummets.
 - **Second attempt** was to simply raise the maximum time each physics tick could take. Originally it was ~60 ticks per second and lowering it to ~30 caused no major visual differences, and the performance was vastly improved. But of course, there wasn't enough boids to make it look REALLY cool so we had to do more. Bryan was able to get to 40K-60K boids so I knew we were able to get more.
 - **Third attempt** was to use multithreading. The original idea was to have a background thread calculate all steering behaviours, weights, everything, all in the background. Once it was finished, it would then signal a mutex that the physics thread then knew it was ready to push to the multimeshes. 
 Although this works in theory, this caused extreme performance loss as Godot seemed to struggle when doing anything that involved the scene tree as physics thread and render thread seem to sync well, but a thread created by me in GDScript didn't have this same robustness. Performance wasn't high enough for the boids count we wanted.

- In many Video Games. When performance drops, the scene might not render at 100%, it might drop to 70% instead. I thought *"Why not do something similar with the maximum Physics Tick time?"*. So for the **Fourth attempt**, a score was given. If the FPS dropped below a certain threshold, the score quickly dropped, if the performance was "ok", it slowly raised back up. At the end of the frame, the physics tick rate was determined based off this. 
This meant we could have a Physics tick rate of 30 times per second, but if performance got back and we were about to have a [Physics Death Spiral](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-physics-common-max-physics-steps-per-frame), the Physics tick rate would lower, maybe down to 5 temporarily, Just to ensure that we never had a spiral. 
Once performance stabilised, the tick rate would rise back to normal slowly. We were able to break the 40K boid barrier with this method, but we wanted to get to 6-digit boid counts. 

- After a while I noticed that using functions like [MultiMeshes](https://docs.godotengine.org/en/stable/classes/class_multimesh.html#class-multimesh-method-get-instance-transform)' `Get_Instance_Transform()` were fine for a few thousand boids. But when we got to 10K -> 30K, the profiler really complained about it. 
This is because Multimeshes have all data primarily stay on the GPU *(Mesh GPU instancing)*. 
The flow of data is the CPU to the GPU, then getting all the Transform3D's from the GPU to the CPU, calculate new boid transforms, then back to the GPU to render it. 
My **Fifth attempt** was to make a **PackedFloat32Array** *(the same one used by the MultiMesh)* which stores all the transforms of all boids. Although this was hell as we were dealing with the raw numbers rather than having everything as a Transform3D type which would make development easier, this made sure that the flow of data was strictly from the CPU, to the GPU, and that's it.
We easily got up to 6-digit boid counts. This by far had the biggest impact... but we still wanted to make it cooler... so **MORE BOIDS**!!!


#### The Solution

So from what we learnt in previous attempts:
 
 - We can't use external separate threads due to sync issues with anything affecting the scene tree.

 - Physics tick can NEVER take more time than is allocated to it, otherwise a [Physics Death Spiral](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-physics-common-max-physics-steps-per-frame) occurs.
 - Render thread is off-limits for any behaviour/steering calculations of **ALL** boids.
 
 - MultiMeshes functionality for **Setting** buffers is great and quick, but **Getting** buffers and instance transforms, is unacceptably slow. 
 
Using what we learnt. The final attempt was the **"Offbrand Physics DLSS"**. Making use of Godot Multimesh [set buffer interpolated](https://docs.godotengine.org/en/stable/classes/class_multimesh.html#class-multimesh-method-set-buffer-interpolated) 
I got 2 **PackedFloat32Array**'s. Every frame, there will be the "**Current**" **buffer**, and a "**Previous**" **buffer**. We do all our boid behaviour maths and edit transforms on the Current buffer. We then set the Multimesh to interpolate between the previous buffer, and the current one.

The next frame, they switch. The current buffer is now marked as the "previous buffer", and the old previous buffer is now marked as the current buffer. 
This swap means although the physics tick could be 15, it's effectively doubled to 30.

This swapping of buffers, coupled with the runtime physics tick adjuster mentioned in the **Fourth Attempt**, means we could get up to ~210,000 boids on screen. 


#### Issues

Originally I was going to have bolts and projectiles also using this "Offbrand Physics DLSS". I made sure that all planets and ships shared the same "Damage" interface *(it's `Damagable.gd`)* so that boids when shooting a planet just had to call the Damage interface.

The issue was that getting projectiles to work was too janky. 
 - Bolts would appear from nowhere, or disappear immediately. 
 - Corruption of Transform's meant we got seizure-inducing visuals.
 - Projectiles wouldn't move at the correct velocities, if at all.
 - Performance tanked to unacceptable levels.

I tried to re-write the old mangled boid code, leading to `Boid_Manager_V2.gd` and `Boid_Manager_V3.gd`, but this didn't solve the issues.
I learnt that writing cleaner code from the start could've made the boid system more maintainable. Using the `class_name` type in Godot from the start could have allowed for greater OOP operability.

If I were to do this project again, with the knowledge I have now, I would make sure that my code, for boid manager and even the solar system/planets code, all follow SOLID principles from the planning stage, rather than implementing the SOLID principles during implementation.



