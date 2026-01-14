# DINO ROYALE - Game Design Document
*Complete Edition v1.1*

---

DINO ROYALE

Survival of the Fittest

GAME DESIGN DOCUMENT

Roblox Battle Royale Shooter

A prehistoric-themed battle royale experience

featuring dinosaurs, survival mechanics, and intense combat

Version 1.1 | January 2026


## Table of Contents

1. Executive Summary

2. Core Game Concept

3. Map Design: Isla Primordial

4. Weapons System

5. Dinosaur System

6. Items & Equipment

7. Game Modes

8. Progression & Monetization

9. Controls & Input

10. Tutorial & Onboarding

11. Social Features

12. UI/UX Design

13. Audio Design

14. Technical Specifications

15. Accessibility Features

16. Safety & Moderation

17. Analytics & Telemetry

18. Localization

19. Seasonal Content Plan

20. Art Direction & Visual Style

Appendix A: Quick Reference Stats

Appendix B: Development Roadmap


## 1. Executive Summary

Dino Royale is a Roblox battle royale shooter set in a Jurassic Park-inspired world where up to 100 players compete to be the last survivor. Unlike Fortnite, this game features no building mechanics, instead emphasizing tactical positioning, dinosaur encounters, and environmental hazards unique to a prehistoric setting.

Players drop onto Isla Primordial, a massive island featuring diverse biomes including dense jungles, volcanic regions, swamps, and abandoned research facilities. The game distinguishes itself through dynamic dinosaur AI that acts as both threat and opportunity, environmental storytelling through ruined facilities, and unique prehistoric-themed weapons and vehicles.


### Key Differentiators

No Building: Pure gunplay and tactical cover usage, unlike Fortnite

Living Ecosystem: 20+ dinosaur species with unique AI behaviors

Environmental Hazards: Volcanic eruptions, stampedes, and prehistoric storms

Iconic Theme: Beloved dinosaur aesthetic appeals to broad audience


### Target Audience

Primary: Roblox players aged 9-16 who enjoy battle royale games. Secondary: Dinosaur enthusiasts and fans of the Jurassic franchise. The game maintains a T-rated experience suitable for Roblox's audience while delivering exciting combat.


### Platform & Requirements


| Platform | Minimum Specs | Recommended Specs |
|---|---|---|
| PC (Windows) | Intel i3 / 4GB RAM / Integrated GPU | Intel i5 / 8GB RAM / GTX 1050 |
| PC (Mac) | M1 or Intel i5 / 4GB RAM | M1 Pro or Intel i7 / 8GB RAM |
| Mobile (iOS) | iPhone 8 / iOS 14+ | iPhone 12+ / iOS 15+ |
| Mobile (Android) | Snapdragon 660 / 3GB RAM | Snapdragon 845+ / 6GB RAM |
| Xbox | Xbox One S | Xbox Series S/X |
| Tablet | iPad 6th Gen / Android Tab S6 | iPad Pro / Tab S8 |


## 2. Core Game Concept


### 2.1 Game Pillars

Survival Combat: Pure gunplay and tactical positioning without building distractions

Living World: Dinosaurs roam the map as dynamic threats and opportunities

Environmental Storytelling: Discover the mystery of what happened to Isla Primordial

Accessibility: Easy to learn, rewarding to master for Roblox's audience


### 2.2 Match Flow


| Phase | Duration | Description |
|---|---|---|
| Pre-Game Lobby | 60 seconds | Players gather in helicopter hangar, customize loadouts |
| Deployment | 90 seconds | Helicopter flies over island; players choose drop zone |
| Early Game | 0-5 minutes | Loot weapons, gather supplies, encounter first dinosaurs |
| Mid Game | 5-15 minutes | Storm closes in, rotations, dinosaurs become aggressive |
| End Game | 15-20 minutes | Final circle, intense firefights, apex predators spawn |


### 2.3 The Storm System: Extinction Wave

Instead of a traditional storm, Dino Royale features the "Extinction Wave" - a deadly volcanic ash cloud that closes in on the island. This thematically fits the prehistoric setting while serving the same gameplay purpose.


| Circle | Wait Time | Shrink Time | Damage/Sec | Size |
|---|---|---|---|---|
| 1 | 180 sec | 120 sec | 1 HP | 100% |
| 2 | 120 sec | 90 sec | 2 HP | 60% |
| 3 | 90 sec | 60 sec | 5 HP | 35% |
| 4 | 60 sec | 45 sec | 8 HP | 15% |
| 5 | 45 sec | 30 sec | 10 HP | 5% |
| Final | 30 sec | Closes | 15 HP | 0% |


## 3. Map Design: Isla Primordial

The map is divided into distinct biomes, each with unique dinosaurs, loot density, and environmental hazards. The island tells the story of a failed genetic research facility through environmental details and collectible lore items.


### 3.1 Biome Overview


| Biome | Key Locations | Dinosaurs | Loot Tier |
|---|---|---|---|
| Jungle Zone | Visitor Center, Raptor Paddock, Maintenance Shed | Velociraptors, Dilophosaurus, Compsognathus | Medium-High |
| Open Plains | Herbivore Valley, Safari Lodge, Feeding Stations | Triceratops, Brachiosaurus, Gallimimus | Medium |
| Volcanic Region | Geothermal Plant, Lava Caves, Observatory | T-Rex Territory, Carnotaurus | High (Risky) |
| Swamplands | River Delta, Research Outpost, Boat Dock | Spinosaurus, Baryonyx, Pteranodon | Medium |
| Coastal Area | Harbor, Lighthouse, Beach Resort | Mosasaurus (water), Dimorphodon | Low-Medium |
| Research Complex | Main Lab, Hatchery, Control Room, Server Hub | Indoraptor (Rare Boss) | Very High |


### 3.2 Major Points of Interest (POIs)


#### Visitor Center (Hot Drop)

The iconic main building featuring a grand rotunda with dinosaur skeletons, gift shop, restaurant, and control room. High loot density attracts many players. Velociraptors patrol the kitchen area. Multiple entry points and verticality make for intense early-game fights.


#### T-Rex Paddock

A massive fenced area (fence is broken) where the T-Rex roams. Goat feeding station contains legendary loot but approaching triggers the T-Rex. High risk, high reward location. Observation tower provides sniping position.


#### Hammond's Villa

Luxurious hilltop mansion with excellent sightlines. Contains a hidden bunker with rare weapons. Amber collection room tells backstory through collectible lore items. Helicopter pad allows quick rotations.


#### Genetics Laboratory

Underground facility with multiple floors. Embryo storage room has highest-tier loot but may spawn the Indoraptor boss. Emergency lockdown system can trap players inside. Server room contains keycard for restricted areas.


#### Raptor Paddock

Fenced enclosure with walkways above. 3-5 Velociraptors always spawn here. Observation catwalk provides safe looting but is exposed. Feeding pen has guaranteed epic weapons. Watch for coordinated raptor attacks.


#### Geothermal Plant

Industrial facility near the volcano. Steam vents provide cover but deal damage. Control room overlooks the main floor. Periodic eruption events add environmental hazard. Contains vehicle spawns.


### 3.3 Map Layout

The island is approximately 4km x 4km with the following general layout:

NORTH: Volcanic Region (High Danger Zone)

- Geothermal Plant, Lava Caves, T-Rex Paddock

CENTER: Jungle & Research (Main POIs)

- Visitor Center, Research Complex, Hammond Villa

EAST: Swamplands (Medium Danger)

- River Delta, Research Outpost, Boat Dock

WEST: Open Plains (Beginner Friendly)

- Herbivore Valley, Safari Lodge, Feeding Stations

SOUTH: Coastal Area (Mixed)

- Harbor, Lighthouse, Beach Resort, Aviary


### 3.4 Environmental Events


| Event | Trigger | Effect |
|---|---|---|
| Volcanic Eruption | Random (North zone) | Lava bombs rain down, forces rotation south |
| Stampede | Loud gunfire in Plains | Herbivores charge across area, damages all in path |
| Power Outage | Mid-game trigger | Facility lights go out, Indoraptor released |
| Pteranodon Swarm | Near Aviary | Flying dinos attack exposed players |
| Monsoon | Random | Reduced visibility, dinosaurs seek shelter |


## 4. Weapons System

Weapons follow a rarity system (Common, Uncommon, Rare, Epic, Legendary) with prehistoric theming. All weapons are fictional variants that fit the aesthetic while providing satisfying gunplay.


### 4.1 Weapon Categories


| Category | Weapons | Best Use | Ammo Type |
|---|---|---|---|
| Assault Rifles | Ranger AR, Expedition Rifle, Predator Carbine | Medium range, versatile | Medium Rounds |
| SMGs | Raptor SMG, Jungle Sprayer, Compact Survivor | Close quarters combat | Light Rounds |
| Shotguns | Rex Blaster, Safari Pump, Dino Devastator | Close range, high burst | Shells |
| Sniper Rifles | Tranq Rifle, Spotter's Choice, Apex Hunter | Long range elimination | Heavy Rounds |
| Pistols | Ranger Sidearm, Survivor's Friend, Desert Claw | Backup weapon | Light Rounds |
| DMRs | Scout Marksman, Park Warden, Precision Ranger | Mid-long range | Heavy Rounds |
| Special | Amber Launcher, Electro Net Gun, Dino Call | Utility and dino interaction | Special Ammo |


### 4.2 Weapon Stats by Rarity

Each rarity tier increases base damage by approximately 10% and improves other stats:


| Rarity | Damage Mult | Reload Speed | Mag Size | Drop Rate |
|---|---|---|---|---|
| Common (Gray) | 1.0x | Base | Base | 40% |
| Uncommon (Green) | 1.1x | -5% | +0 | 30% |
| Rare (Blue) | 1.2x | -10% | +2 | 18% |
| Epic (Purple) | 1.3x | -15% | +4 | 9% |
| Legendary (Gold) | 1.4x | -20% | +6 | 3% |


### 4.3 Detailed Weapon Statistics


#### Assault Rifles


| Weapon | Damage | Fire Rate | Mag Size | Reload | Range |
|---|---|---|---|---|---|
| Ranger AR | 32 | 5.5/sec | 30 | 2.5s | Medium |
| Expedition Rifle | 36 | 4.5/sec | 25 | 2.8s | Long |
| Predator Carbine | 28 | 7.0/sec | 35 | 2.2s | Medium |


#### SMGs


| Weapon | Damage | Fire Rate | Mag Size | Reload | Range |
|---|---|---|---|---|---|
| Raptor SMG | 18 | 10.0/sec | 30 | 2.0s | Short |
| Jungle Sprayer | 15 | 12.0/sec | 40 | 2.5s | Short |
| Compact Survivor | 22 | 8.0/sec | 25 | 1.8s | Short-Med |


#### Shotguns


| Weapon | Damage | Fire Rate | Mag Size | Reload | Spread |
|---|---|---|---|---|---|
| Rex Blaster | 95 | 1.0/sec | 8 | 6.5s | Wide |
| Safari Pump | 110 | 0.7/sec | 5 | 4.5s | Tight |
| Dino Devastator | 140 | 0.5/sec | 2 | 3.0s | Tight |


#### Sniper Rifles


| Weapon | Damage | Fire Rate | Mag Size | Reload | Scope |
|---|---|---|---|---|---|
| Tranq Rifle | 85 | 0.8/sec | 10 | 3.0s | 4x |
| Spotter's Choice | 105 | 0.5/sec | 5 | 3.5s | 6x |
| Apex Hunter | 150 | 0.3/sec | 3 | 4.0s | 8x |


#### Pistols


| Weapon | Damage | Fire Rate | Mag Size | Reload | Range |
|---|---|---|---|---|---|
| Ranger Sidearm | 25 | 4.0/sec | 12 | 1.5s | Short |
| Survivor's Friend | 35 | 2.5/sec | 8 | 1.8s | Medium |
| Desert Claw | 55 | 1.5/sec | 7 | 2.0s | Medium |


#### DMRs (Designated Marksman Rifles)


| Weapon | Damage | Fire Rate | Mag Size | Reload | Scope |
|---|---|---|---|---|---|
| Scout Marksman | 48 | 2.5/sec | 15 | 2.5s | 2x |
| Park Warden | 58 | 2.0/sec | 12 | 2.8s | 3x |
| Precision Ranger | 68 | 1.5/sec | 10 | 3.0s | 4x |


### 4.4 Special Weapons


#### Electro Net Gun (Epic)

Fires an electrified net that slows players by 50% for 3 seconds and stuns small dinosaurs for 5 seconds. Can disable vehicles temporarily. Found only in research facilities. Magazine: 3 nets, Reload: 4 seconds.


#### Dino Call (Rare)

Emits sounds that attract nearby dinosaurs to a targeted location within 100m. Different variants attract different species. Can be used to ambush enemies or create distractions. Uses: 5 per item. Cooldown: 15 seconds.


#### Amber Launcher (Legendary)

Fires explosive amber projectiles that create sticky zones on impact (4m radius). Enemies caught in amber are slowed by 70%. Amber zones persist for 10 seconds. Damage: 50 on direct hit. Magazine: 4 shots.


#### Tranquilizer Dart Gun (Epic)

Fires tranquilizer darts that put small dinosaurs to sleep and slow players significantly. Can be used to safely bypass dinosaur encounters. Damage: 15 to players, applies drowsy effect for 5 seconds. Magazine: 6 darts.


#### Flamethrower (Legendary)

Short-range continuous fire weapon that deals burn damage over time. Extremely effective against dinosaurs. Creates fire patches on ground lasting 5 seconds. Damage: 12/tick + 5 burn. Fuel: 100 units, drains 10/sec.


## 5. Dinosaur System

Dinosaurs are AI-controlled creatures that add a third-party threat element to matches. They follow behavioral patterns, have territories, and can be manipulated by skilled players. This system is what truly sets Dino Royale apart from other battle royale games.


### 5.1 Dinosaur Roster


| Tier | Species | Behavior | Damage | Loot Drop |
|---|---|---|---|---|
| Common | Compsognathus | Passive, flees from players | 5 HP (swarm) | Small Meds |
| Common | Gallimimus | Flees, stampedes when scared | 10 HP (trample) | Ammo |
| Uncommon | Dilophosaurus | Territorial, spits venom | 15 HP + blind | Ammo, Meds |
| Uncommon | Triceratops | Charges if threatened | 40 HP (charge) | Shield items |
| Rare | Velociraptor | Pack hunter, intelligent | 30 HP per bite | Rare weapons |
| Rare | Baryonyx | Hunts near water | 35 HP | Rare items |
| Rare | Pteranodon | Swoops from above | 25 HP + knockback | Mobility items |
| Epic | Carnotaurus | Aggressive pursuit predator | 60 HP | Epic weapons |
| Epic | Spinosaurus | Swamp apex, semi-aquatic | 70 HP | Epic items |
| Legendary | Tyrannosaurus Rex | Apex predator, territorial | 100 HP | Legendary loot |
| Legendary | Indoraptor | Hybrid boss, hunts players | 80 HP (fast) | Legendary+ |


### 5.2 AI Behavior Systems


#### Aggro System

Vision Cones: Most dinosaurs have 120° frontal vision, raptors have 180°

Hearing Range: Gunshots alert dinos within 100m, sprinting within 30m

Smell (T-Rex only): Can detect wounded players within 50m


#### Pack Behavior (Raptors)

Velociraptors spawn in packs of 3-5 and coordinate attacks. One raptor will distract while others flank. They communicate through calls and will retreat if the alpha is killed. Pack size decreases as match progresses.


#### Territorial Behavior

Large predators (T-Rex, Spinosaurus) have defined territories they patrol. Entering their territory increases aggro chance. They will chase intruders to territory edge then return. Territory boundaries visible on map as danger zones.


### 5.3 Boss Encounters


#### T-Rex Rampage Event

Trigger: Random mid-game event (Circle 3-4)

Warning: Ground tremors and roar heard map-wide 30 seconds before

Behavior: T-Rex breaks containment, roams toward most player activity

Health: 2000 HP, takes reduced damage from common weapons

Reward: Killing drops 3 legendary items, creates 30-second safe zone


#### Indoraptor Hunt

Trigger: End-game event (Final 10 players)

Warning: Power outage in Research Complex, emergency alarms

Behavior: Actively hunts players, can open doors, extremely fast

Health: 1500 HP, vulnerable to headshots

Reward: Killing guarantees bonus rewards even without victory


### 5.4 Player Interaction with Dinosaurs


| Action | Result |
|---|---|
| Use Dino Call | Attract specific species to targeted location |
| Throw Meat Bait | Lure carnivores to bait location for 20 seconds |
| Use Dino Repellent | Create 10m safe zone for 30 seconds |
| Deploy Flare | Dinosaurs avoid flare area, draws player attention |
| Kill Dinosaur | Drops loot based on tier, alerts nearby predators |
| Crouch/Prone | Reduced detection range by dinosaurs |


## 6. Items & Equipment


### 6.1 Healing Items


| Item | Effect | Use Time | Notes |
|---|---|---|---|
| Bandage | +15 HP | 3 sec | Common, stack x15, heals up to 75 HP |
| Med Kit | +75 HP | 7 sec | Uncommon, stack x5 |
| Dino Adrenaline | Full HP +25 | 10 sec | Rare, overheal decays over 30s |
| Shield Serum | +50 Shield | 4 sec | Common, max 100 shield total |
| Mega Serum | +100 Shield | 8 sec | Rare, full shield restore |
| Slurp Canteen | +75 HP & Shield | 5 sec | Epic, heals both over time |


### 6.2 Tactical Equipment


| Equipment | Stack | Function |
|---|---|---|
| Flare | x6 | Throwable that attracts dinosaurs and marks enemy locations |
| Smoke Bomb | x4 | Creates visual cover, confuses dinosaur AI for 5 seconds |
| Grapple Hook | x3 | 50m range, quick traverse, escape dinosaurs, reach high ground |
| Motion Sensor | x2 | Deployable, detects players and dinos in 30m radius for 60 sec |
| Dino Repellent | x2 | Spray creating 10m dinosaur-free zone for 30 seconds |
| Meat Bait | x4 | Throwable lure for carnivores, lasts 20 seconds |
| Frag Grenade | x6 | Explosive, 70 damage center, 5m blast radius |
| Flashbang | x4 | Blinds players and panics dinosaurs for 3 seconds |


### 6.3 Vehicles


| Vehicle | Seats | Speed | Health | Special |
|---|---|---|---|---|
| Explorer Jeep | 4 | Fast | 800 | Iconic design, all-terrain capable |
| ATV | 2 | Very Fast | 400 | Quick escapes, low protection |
| Tour Vehicle | 6 | Medium | 1000 | Follows rail paths, very safe |
| Helicopter | 4 | Fast | 600 | Rare spawn, attracts Pteranodons |
| Boat | 4 | Medium | 500 | Water travel, beware Mosasaurus |
| Motorcycle | 1 | Fastest | 200 | Solo rotation, very exposed |


## 7. Game Modes


### 7.1 Core Modes


#### Solo (100 Players)

Classic battle royale - every player for themselves. Last one standing wins. Full dinosaur spawns and all map zones active. Recommended for experienced players who want the purest survival experience.


#### Duos (50 Teams of 2)

Team up with a partner. Downed teammates can be revived within 90 seconds using 5-second channel. Shared pings, communication wheel, and team highlighting. Vehicles prioritize 2-seaters in loot spawns.


#### Squads (25 Teams of 4)

Four-player teams with full revival mechanics. Reboot Beacons allow respawning eliminated teammates by collecting their tags and using beacon stations. Team vehicles (Jeeps, Tour Vehicles) spawn more frequently.


### 7.2 Limited Time Modes (LTMs)


| Mode Name | Description |
|---|---|
| Extinction Event | Meteor shower replaces storm. Survive falling meteors while fighting. Dinosaurs panic and become hyper-aggressive. |
| Night Hunt | Match at night with limited visibility. Flashlights required. Nocturnal predators more active. Night vision as epic loot. |
| Dino Tamer | Special saddles allow mounting certain dinosaurs. Ride Triceratops, Raptors, and Gallimimus into battle. |
| Jurassic Hunt | Asymmetric: one team plays as Velociraptors (respawn enabled), others as survivors (no respawn). Last survivor wins. |
| Big Game Safari | 50v50 team mode. Compete to hunt the most dinosaurs. PvP enabled. Boss dinosaurs worth bonus points. |
| Classic Mode | No dinosaurs, traditional BR experience. For players who want pure PvP gunfight gameplay. |
| Sniper Showdown | Only sniper rifles and pistols spawn. Reduced player count (50). Long-range combat focus. |
| Close Quarters | Only shotguns and SMGs. Faster storm. Raptors everywhere. Jungle biome only. |


### 7.3 Ranked Mode

Competitive ranked play with placement-based matchmaking. Seasons last 2 months with rank resets. Rewards include exclusive cosmetics, titles, and profile badges.


| Rank | Points Required | Player % | Reward |
|---|---|---|---|
| Bronze | 0-1499 | 40% | Bronze Badge |
| Silver | 1500-2999 | 30% | Silver Badge + Spray |
| Gold | 3000-4499 | 18% | Gold Set + Trail |
| Platinum | 4500-5999 | 8% | Platinum Set + Glider |
| Diamond | 6000-7499 | 3% | Diamond Set + Skin |
| Apex Predator | 7500+ | 1% | Exclusive Legendary Set |


## 8. Progression & Monetization


### 8.1 Battle Pass System

Each season features a themed Battle Pass with 100 tiers of rewards. Free track available to all players with premium track requiring Robux purchase (typically 950 Robux). Season duration: 10 weeks.


| Tier Range | Free Track Rewards | Premium Track Rewards |
|---|---|---|
| 1-25 | Common skins, emotes, XP boosts | Uncommon skins, vehicle wraps, 200 V-Bucks |
| 26-50 | Uncommon items, profile icons, banners | Rare skins, weapon skins, dinosaur pets |
| 51-75 | Rare items, banner frames, loading screens | Epic skins, gliders, back bling, 300 V-Bucks |
| 76-100 | Epic items, exclusive emote | Legendary skin, exclusive dino pet, pickaxe |


### 8.2 Cosmetic Categories

Character Skins: Park rangers, scientists, hunters, dinosaur-themed outfits, movie homages

Weapon Skins: Amber, fossil, jungle camo, volcanic, prehistoric patterns

Gliders: Pteranodon wings, parachutes with dino prints, hang gliders, leaf gliders

Back Bling: Baby dinosaurs (animated), amber backpacks, research equipment, raptor claws

Trails: Footprint effects, amber particles, prehistoric plants, fossil dust

Emotes: Dino roars, paleontologist dances, famous movie references, excavation animations

Vehicle Wraps: Dino patterns, jungle camo, park tour designs, volcanic themes

Pickaxes/Tools: Fossil picks, amber hammers, dinosaur bones, excavation tools


### 8.3 Shop Structure

Daily rotating shop with featured and daily items. Special event shops during limited time modes. All purchases are cosmetic only - no gameplay advantages.


| Item Type | Price Range (Robux) | Availability |
|---|---|---|
| Legendary Skin | 1500-2000 | Featured (48 hours) |
| Epic Skin | 800-1200 | Featured/Daily |
| Rare Skin | 400-800 | Daily rotation |
| Emotes | 200-500 | Daily rotation |
| Bundles | 1500-2500 | Limited time |


## 9. Controls & Input


### 9.1 PC Controls (Keyboard & Mouse)


| Action | Default Binding | Alt Binding |
|---|---|---|
| Move Forward | W | Up Arrow |
| Move Backward | S | Down Arrow |
| Move Left | A | Left Arrow |
| Move Right | D | Right Arrow |
| Jump | Space | - |
| Crouch | Left Ctrl | C |
| Prone | Z | - |
| Sprint | Left Shift | - |
| Fire Weapon | Left Mouse | - |
| Aim Down Sights | Right Mouse | - |
| Reload | R | - |
| Interact/Pickup | E | F |
| Inventory | Tab | I |
| Map | M | - |
| Weapon Slot 1 | 1 | - |
| Weapon Slot 2 | 2 | - |
| Weapon Slot 3 | 3 | - |
| Weapon Slot 4 | 4 | - |
| Weapon Slot 5 | 5 | - |
| Use Equipment | Q | G |
| Ping/Mark | Middle Mouse | X |
| Push to Talk | V | - |
| Emote Wheel | B | - |


### 9.2 Controller Layout (Xbox/PlayStation)


| Action | Xbox | PlayStation |
|---|---|---|
| Move | Left Stick | Left Stick |
| Look/Aim | Right Stick | Right Stick |
| Jump | A | X |
| Crouch/Prone (hold) | B | Circle |
| Sprint (toggle) | L3 (click) | L3 (click) |
| Fire Weapon | RT | R2 |
| Aim Down Sights | LT | L2 |
| Reload | X | Square |
| Interact/Pickup | X (hold) | Square (hold) |
| Switch Weapon | Y | Triangle |
| Use Equipment | RB | R1 |
| Tactical Equipment | LB | L1 |
| Map | View Button | Touchpad |
| Inventory | Menu Button | Options |
| Ping/Mark | D-Pad Up | D-Pad Up |
| Emote Wheel | D-Pad Down | D-Pad Down |


### 9.3 Mobile Touch Controls

Mobile controls feature a customizable HUD with draggable buttons. Default layout optimized for thumb reach on both phones and tablets.


| Element | Position | Function |
|---|---|---|
| Virtual Joystick (Left) | Bottom-left | Movement control |
| Look Area (Right) | Right half of screen | Camera/aim control |
| Fire Button | Bottom-right | Shoot weapon |
| ADS Button | Above fire button | Aim down sights toggle |
| Jump Button | Right of joystick | Jump action |
| Crouch Button | Above jump | Crouch toggle |
| Reload Button | Center-right | Reload weapon |
| Weapon Slots | Top-right | Quick weapon switch |
| Interact Prompt | Center (context) | Auto-appears near loot |
| Inventory Button | Top-left | Open inventory |
| Map Button | Top-left | Open/close map |
| Ping Button | Center-right | Quick ping location |


### 9.4 Control Customization Options

Custom Bindings: Full key remapping for all actions

Sensitivity: 0.1 to 10.0 scale with separate X/Y axis options

Toggle Options: Toggle or hold options for sprint, crouch, and ADS

Aim Assist (Controller): Adjustable 0-100% with per-weapon settings

Dead Zones: Linear, exponential, and custom curve options

Invert Controls: Standard, Inverted Y, Inverted X, Full Invert

Gyro Aiming: Option to disable motion controls on Switch/Mobile


## 10. Tutorial & Onboarding


### 10.1 First-Time User Experience (FTUE)

New players are guided through a structured onboarding sequence designed to teach core mechanics without overwhelming them. The tutorial is skippable for experienced BR players.


#### Tutorial Island (Offline Training)

A separate small map where players learn basics before entering live matches. Features AI dinosaurs and target dummies. Completion rewards: Starter skin + 100 XP boost.


| Stage | Duration | Skills Taught |
|---|---|---|
| 1. Movement Basics | 2 min | Walking, sprinting, jumping, crouching, prone |
| 2. Looting & Inventory | 3 min | Picking up items, weapon slots, ammo types, healing |
| 3. Combat Training | 4 min | Shooting, ADS, reloading, headshots, weapon switching |
| 4. Dinosaur Encounters | 3 min | Identifying dinos, threat levels, using repellent/bait |
| 5. Vehicle Basics | 2 min | Entering/exiting, driving, fuel management |
| 6. Storm Survival | 2 min | Reading the map, circle timings, rotation strategies |
| 7. Practice Match | 5 min | Full loop with bots, ends at Top 10 |


### 10.2 Progressive Tips System

Context-sensitive tips appear during first 10 matches based on player actions and situations.


| Trigger | Tip Displayed |
|---|---|
| First landing | Press E to pick up weapons and items quickly! |
| Low health | Use bandages or Med Kits to heal. Open inventory with TAB. |
| Near dinosaur | Crouch to reduce detection! Dinosaurs hunt by sight and sound. |
| Storm approaching | The Extinction Wave is coming! Check your map (M) for safe zones. |
| First elimination | Great shot! Eliminated players drop all their loot. |
| Downed in Duos | Your teammate can revive you! Crawl to safety. |
| Found vehicle | Press E to enter vehicles. They make noise that attracts dinosaurs! |
| Rare loot found | Purple and Gold items are powerful! Manage inventory space wisely. |
| Raptor nearby | Raptors hunt in packs. If you see one, others are close! |
| Match Top 10 | You made Top 10! Play carefully - the circle is small now. |


### 10.3 Training Grounds (Persistent)

Always-accessible practice area from main menu for testing weapons, practicing aim, and experimenting with dinosaur interactions without match pressure.

Weapon Range: All weapons available at all rarities for comparison

Target Practice: Moving and stationary targets with hit tracking

Dino Arena: Spawnable dinosaurs of all types for practice encounters

Vehicle Course: Test all vehicles on a dedicated track

Private Duels: 1v1 practice with friends


## 11. Social Features


### 11.1 Friends System


| Feature | Description |
|---|---|
| Friend Requests | Send/receive via username or Roblox friends list |
| Friends List | View online status, current activity, join buttons |
| Best Friends | Pin up to 10 friends for quick access |
| Recently Played | Last 20 players you matched with |
| Block List | Blocked players never matched with you |
| Online Status | Online, In Match, In Menu, Away, Invisible options |


### 11.2 Party System

Players can form parties of up to 4 for squad modes, with party leader controlling matchmaking.

Party Invites: Send via friends list or shareable party code

Party Chat: Text and voice while in party lobby

Persistent Party: Stays together across multiple matches

Auto-Fill Option: Fill remaining slots with randoms or play short-handed

Party Leader: Visual crown indicator, transfer via vote or leave


### 11.3 Clan System


| Feature | Description |
|---|---|
| Clan Creation | 500 Robux to create, custom name/tag/emblem |
| Clan Size | Up to 50 members |
| Roles | Leader, Officers (5 max), Members |
| Clan Chat | Persistent text channel for all members |
| Clan Leaderboard | Combined stats, weekly/seasonal rankings |
| Clan Challenges | Weekly missions for bonus XP and cosmetics |
| Clan Bank | Shared currency for clan unlocks |
| Clan Emblem | Displayed on player banners and nameplates |


### 11.4 Communication Tools

Voice Chat: Proximity-based (50m) and team-only options

Text Chat: Team, All (lobby only), Whisper, Clan channels

Communication Wheel: Quick communication without voice - Ping, Help, Enemy, Loot, etc.

Ping System: Mark locations, enemies, loot for teammates with contextual callouts

Emotes: Play emotes visible to all nearby players


### 11.5 Spectator Mode

After elimination, players can spectate their killer or teammates (in team modes).

Free Spectate: Follow killer or teammates through match end

Anti-Cheat: No spectator info sharing to prevent ghosting (delayed 30 sec)

Report Option: Report suspicious players while spectating


## 12. UI/UX Design


### 12.1 HUD Elements

Health/Shield Bar: Bottom left, amber-colored health, blue shield

Minimap: Top right, shows storm, teammates, dinosaur warnings

Inventory Bar: Bottom center, 5 weapon slots + equipment

Ammo Counter: Bottom right, current weapon ammo

Kill Feed: Top left, shows eliminations including dinosaur kills

Dinosaur Proximity: Pulsing indicator when large predators nearby

Damage Direction: Directional indicators for gunshots and footsteps

Storm Info: Top center, storm timer and distance

Hit Markers: Visual and audio cues for hits

Player Count: Top right corner, updates in real-time


### 12.2 HUD Layout Diagram

+------------------------------------------------------------------+

|  [Kill Feed]              [Storm Timer]         [Player Count]  |

|                                                      [Minimap]   |

|                                                                  |

|                                                                  |

|                        [Center Screen]                           |

|                         [Crosshair]                              |

|                       [Damage Indicators]                        |

|                                                                  |

|                                                                  |

|  [Health Bar]                                    [Ammo Counter]  |

|  [Shield Bar]         [Weapon Slots 1-5]         [Equipment]     |

+------------------------------------------------------------------+


### 12.3 Menu Structure


| Menu | Sub-Menus | Description |
|---|---|---|
| Play | Solo, Duos, Squads, Ranked, LTMs | Game mode selection and matchmaking |
| Locker | Skins, Weapons, Gliders, Emotes, Loadouts | Cosmetic customization |
| Shop | Featured, Daily, Bundles, Battle Pass | Purchase cosmetics with Robux |
| Career | Stats, Achievements, Bestiary, Lore | Player progression and records |
| Social | Friends, Party, Clan, Recent Players | Social features hub |
| Training | Tutorial, Practice Range, Dino Arena | Learning and practice tools |
| Settings | Controls, Audio, Video, Accessibility | Game configuration |


### 12.4 Inventory Screen

Full-screen inventory accessible via Tab key. Shows equipped weapons, consumables, ammo counts, and nearby ground loot for quick swapping.

Weapon Management: Drag-and-drop or click to equip/swap

Consumable Stacks: Stack splitting with Shift+Click

Ammo Overview: Shows live ammo for each type

Proximity Loot: Quick pickup from ground loot

Drop Items: Right-click to drop items


## 13. Audio Design


### 13.1 Audio Categories & Priorities


| Category | Priority | Description | Volume Default |
|---|---|---|---|
| Critical Alerts | 1 (Highest) | Storm warnings, boss spawns, low health | 100% |
| Combat | 2 | Gunfire, explosions, hit markers | 90% |
| Dinosaurs | 3 | Roars, footsteps, attack sounds | 85% |
| Player Actions | 4 | Footsteps, healing, reloading | 80% |
| Vehicles | 5 | Engine sounds, horns, crashes | 75% |
| Ambient | 6 | Environment, weather, background life | 60% |
| Music | 7 (Lowest) | Menu, match start, victory/defeat | 50% |
| UI | Overlay | Button clicks, notifications, pings | 70% |


### 13.2 Dinosaur Sound Design


| Dinosaur | Idle Sound | Alert Sound | Attack Sound | Special |
|---|---|---|---|---|
| T-Rex | Low rumble | Thunderous roar | Bone-crushing bite | Footstep tremors |
| Velociraptor | Clicking chirps | Shrill bark | Snarling slash | Pack call response |
| Dilophosaurus | Soft hooting | Neck frill rattle | Venomous spit hiss | Warning croak |
| Triceratops | Gentle grunt | Aggressive snort | Horn charge rumble | Herd calls |
| Pteranodon | High screech | Dive whistle | Talon swoop | Wing flaps |
| Spinosaurus | Deep bellow | Crocodilian hiss | Crushing jaw snap | Water splash |
| Indoraptor | Eerie silence | Echolocation click | Savage screech | Door scratch |


### 13.3 Music System


#### Adaptive Music

Music dynamically adjusts based on game state, seamlessly transitioning between intensity levels.


| Game State | Music Style | Tempo | Instruments |
|---|---|---|---|
| Main Menu | Mysterious, epic | Slow | Orchestra, choir |
| Deployment | Anticipation | Building | Strings, percussion building |
| Early Game (Safe) | Exploration | Moderate | Ambient pads, light percussion |
| Combat Nearby | Tension | Faster | Drums, brass accents |
| Active Combat | Action | Fast | Full orchestra, heavy percussion |
| Top 10 | High stakes | Intense | Driving rhythm, dramatic swells |
| Victory | Triumphant | Celebratory | Fanfare, full orchestra |
| Defeat | Somber | Slow | Strings, piano |
| Boss Encounter | Epic threat | Very intense | Full orchestra, dark choir |


### 13.4 3D Audio & Spatial Sound

Surround Sound: Full HRTF support for directional audio awareness

Sound Positioning: Gunshots, footsteps, dinosaur sounds accurately positioned

Occlusion: Sounds travel 30% slower through walls/buildings

Environment Effects: Jungle dampens, caves echo, plains carry far

Distance Attenuation: Gunshots audible at 150m, footsteps at 30m, dino roars at 200m


### 13.5 Audio Accessibility

Visual Sound Effects: On-screen directional indicators for key sounds

Closed Captions: Full subtitle support for dinosaur and environmental sounds

Volume Mixing: Separate sliders for all audio categories

Mono Mode: Optional mono audio with enhanced panning cues


## 14. Technical Specifications


### 14.1 Roblox-Specific Implementation


| System | Implementation Approach |
|---|---|
| Server Architecture | 100-player servers using Roblox's optimized networking layer |
| Map Streaming | StreamingEnabled with aggressive distance culling for large map |
| Dinosaur AI | Server-authoritative pathfinding with client-side prediction |
| Combat System | Raycasting with server validation, anti-exploit checks |
| Data Persistence | DataStore2 or ProfileService for player data |
| Matchmaking | MemoryStoreService for queue management, TeleportService for match joining |
| Anti-Cheat | Server authority on all game state, movement validation, damage verification |


### 14.2 Performance Targets

Target FPS: 60 FPS on mid-range PC, 30 FPS on mobile devices

Load Time: Under 30 seconds from queue to deployment

Network Latency: Sub-100ms ping for responsive gunplay

Memory Usage: Under 2GB client memory

Draw Calls: Optimized to under 1000 per frame


### 14.3 Optimization Strategies

LOD System: Multiple detail levels for dinosaurs, buildings, and vegetation

Culling: Aggressive frustum and occlusion culling for jungle areas

Instance Pooling: Reuse dinosaur instances, projectiles, and effects

Deferred Updates: AI updates staggered across frames


### 14.4 Network Architecture


| System | Update Rate | Authority | Prediction |
|---|---|---|---|
| Player Movement | 60 Hz | Server | Client-side with reconciliation |
| Weapon Fire | 60 Hz | Server | Client hit prediction |
| Dinosaur AI | 20 Hz | Server | Client interpolation |
| Vehicle Physics | 30 Hz | Server | Client prediction |
| Storm Position | 1 Hz | Server | Client extrapolation |
| Loot Spawns | On demand | Server | None |
| Player Stats | On change | Server | None |


## 15. Accessibility Features

Dino Royale is committed to making the game playable by the widest possible audience. All accessibility features are available at no extra cost and can be combined as needed.


### 15.1 Visual Accessibility


| Feature | Description | Default |
|---|---|---|
| Colorblind Modes | Protanopia, Deuteranopia, Tritanopia filters | Off |
| High Contrast UI | Increased contrast for UI elements | Off |
| Large Text Mode | 150% text scaling for menus and HUD | Off |
| Colorblind Loot | Shape-based rarity indicators (circle, square, star, diamond) | Off |
| Enemy Highlight | Outline color options: Red, Yellow, Cyan, Magenta | Red |
| Teammate Colors | Customizable squad member colors | Blue/Green/Orange/Purple |
| Crosshair Options | Size, color, style, center dot customization | Standard White |
| Screen Shake | Reduce/disable camera shake from explosions | On |
| Motion Blur | Disable motion blur effect | On |
| Visual Sound Effects | On-screen indicators for directional sounds | Off |


### 15.2 Audio Accessibility


| Feature | Description | Default |
|---|---|---|
| Closed Captions | Subtitles for all dialogue and key sounds | Off |
| Sound Visualization | Visual indicators for gunshots, footsteps, dinos | Off |
| Mono Audio | Combine stereo to mono with enhanced cues | Off |
| Volume Sliders | Independent control for 8 audio categories | Varies |
| Mute Options | Quick mute for music, voice, all audio | Off |
| Voice Chat Transcription | Real-time text display of voice chat | Off |


### 15.3 Motor Accessibility


| Feature | Description | Default |
|---|---|---|
| Full Remapping | All controls rebindable on all platforms | Standard |
| One-Handed Presets | Left-only and right-only control schemes | Off |
| Toggle Options | Sprint, crouch, ADS as toggle or hold | Hold |
| Auto-Sprint | Always sprint when moving forward | Off |
| Aim Assist | Adjustable 0-100% with multiple styles | 50% |
| Auto-Pickup | Automatically pick up ammo and healing | Off |
| Simplified Controls | Reduced button scheme for core actions only | Off |
| Input Timing | Adjustable double-tap and hold thresholds | Standard |
| Sticky Aim | ADS stays active until pressed again | Off |


### 15.4 Cognitive Accessibility


| Feature | Description | Default |
|---|---|---|
| Tutorial Replay | Access any tutorial section from menu | Available |
| Ping System | Non-verbal communication for all callouts | Enabled |
| Simplified HUD | Show only essential information | Off |
| Extended Timers | Longer countdown timers where applicable | Off |
| Objective Reminders | Periodic reminders of current goals | On |
| Reduced Visual Clutter | Hide non-essential particle effects | Off |
| Pause in Training | Ability to pause in Training Grounds | Enabled |


## 16. Safety & Moderation


### 16.1 Roblox Community Standards Compliance

Dino Royale fully complies with Roblox Community Standards and Terms of Use. The game is designed for players aged 9+ and maintains appropriate content for this audience.


| Requirement | Implementation |
|---|---|
| Age-Appropriate Content | No blood/gore, cartoon violence only, defeated players teleport out |
| No Gambling | Loot boxes are cosmetic only with displayed odds |
| Fair Monetization | No pay-to-win, all gameplay content earnable free |
| Privacy Protection | No personal data collection beyond Roblox defaults |
| Safe Social Features | Filtered chat, report system, parental controls respected |


### 16.2 Chat Moderation

Text Filter: Uses Roblox's built-in text filtering for all chat

Voice Chat: Roblox Spatial Voice with parental consent requirements

Custom Filters: Additional custom filters for game-specific terms and exploits

Toxicity Detection: Automatic detection of toxic patterns with warnings

Escalation: Repeat offenders flagged for human review


### 16.3 Reporting System


| Report Category | Description | Response Time |
|---|---|---|
| Cheating/Exploits | Speed hacks, aimbots, wall hacks | < 24 hours |
| Harassment | Targeted abuse, hate speech, bullying | < 12 hours |
| Inappropriate Content | Bypassing filters, inappropriate avatar | < 24 hours |
| Teaming (Solo) | Unfair cooperation in solo modes | < 48 hours |
| Scamming | Trade fraud, fake giveaways | < 24 hours |
| Spam | Chat spam, ping abuse | < 48 hours |


### 16.4 Punishment System


| Offense Level | First Offense | Second Offense | Third Offense |
|---|---|---|---|
| Minor (spam, light toxicity) | Warning | 1-hour mute | 24-hour mute |
| Moderate (harassment) | 24-hour ban | 7-day ban | 30-day ban |
| Severe (hate speech) | 7-day ban | 30-day ban | Permanent ban |
| Cheating/Exploits | Permanent ban | - | - |
| Real-world threats | Permanent ban + report to Roblox | - | - |


### 16.5 Anti-Cheat Systems

Server Authority: All game state validated server-side, client is display-only

Movement Validation: Speed, teleportation, and position validation

Combat Validation: Fire rate, damage, and ammunition verification

Statistical Detection: Unusual accuracy and reaction time flagging

Player Reports: Community reports reviewed by moderation team

Shadow Pool: Suspected cheaters matched with each other


## 17. Analytics & Telemetry


### 17.1 Data Collection Overview

Analytics are collected to improve game balance, fix bugs, and enhance player experience. All data collection complies with Roblox privacy policies and applicable laws including COPPA.


### 17.2 Gameplay Metrics


| Metric Category | Data Collected | Purpose |
|---|---|---|
| Match Data | Duration, player count, circle locations, winner | Balance, matchmaking |
| Combat | Weapon usage, accuracy, damage dealt/received, K/D | Weapon balancing |
| Movement | Heatmaps, popular drop zones, rotation paths | Map design |
| Dinosaurs | Encounter rates, kill rates, damage taken | AI balancing |
| Loot | Pickup rates, item usage, inventory management | Loot distribution |
| Vehicles | Usage rates, distance traveled, destruction causes | Vehicle balancing |
| Economy | Purchases, Battle Pass progress, shop engagement | Monetization optimization |


### 17.3 Technical Metrics


| Metric | Description | Action Threshold |
|---|---|---|
| Client FPS | Average and minimum FPS by device | < 25 FPS triggers optimization review |
| Server Tick Rate | Server performance stability | < 55 Hz triggers investigation |
| Load Times | Time from queue to gameplay | > 45 sec triggers investigation |
| Crash Reports | Client crash frequency and causes | > 0.5% crash rate triggers hotfix |
| Network Latency | Average ping by region | > 150ms triggers server review |
| Memory Usage | Client memory consumption | > 2.5GB triggers optimization |


### 17.4 Player Engagement Metrics


| Metric | Description | Target |
|---|---|---|
| DAU/MAU | Daily and monthly active users | 30%+ DAU/MAU ratio |
| Session Length | Average playtime per session | 25+ minutes |
| Sessions per Day | Average sessions per active user | 2+ sessions |
| Day 1 Retention | Players returning after first day | 40%+ |
| Day 7 Retention | Players returning after first week | 20%+ |
| Day 30 Retention | Players returning after first month | 10%+ |
| Match Completion | Percentage of matches played to end | 85%+ |
| Battle Pass Completion | Players completing Battle Pass | 15%+ (premium) |


### 17.5 A/B Testing Framework

New features and balance changes are tested with player segments before full rollout.

Control Groups: Control group always maintains current live experience

Rollout Percentage: Testing limited to 5-20% of players initially

Duration: Minimum 48-hour test period for statistical significance

Success Metrics: Retention, engagement, monetization, and player feedback


## 18. Localization


### 18.1 Supported Languages


| Language | Region | Priority | Status |
|---|---|---|---|
| English (US) | North America, Default | P0 - Launch | Complete |
| English (UK) | United Kingdom | P0 - Launch | Complete |
| Spanish (Latin America) | Mexico, South America | P0 - Launch | Complete |
| Spanish (Spain) | Spain | P1 - Month 1 | Planned |
| Portuguese (Brazil) | Brazil | P0 - Launch | Complete |
| French | France, Canada | P1 - Month 1 | Planned |
| German | Germany, Austria | P1 - Month 1 | Planned |
| Japanese | Japan | P1 - Month 1 | Planned |
| Korean | South Korea | P1 - Month 1 | Planned |
| Simplified Chinese | China (if available) | P2 - Month 3 | Planned |
| Traditional Chinese | Taiwan, Hong Kong | P2 - Month 3 | Planned |
| Russian | Russia, CIS | P2 - Month 3 | Planned |
| Polish | Poland | P2 - Month 3 | Planned |
| Italian | Italy | P2 - Month 3 | Planned |
| Turkish | Turkey | P3 - Month 6 | Planned |
| Thai | Thailand | P3 - Month 6 | Planned |
| Vietnamese | Vietnam | P3 - Month 6 | Planned |


### 18.2 Localization Scope


| Content Type | Localized | Notes |
|---|---|---|
| UI Text | Yes | All menus, HUD elements, buttons |
| Tutorial Text | Yes | All tutorial prompts and tips |
| Item Names | Yes | Weapons, consumables, equipment |
| Item Descriptions | Yes | Full descriptions for all items |
| Dinosaur Names | Yes | Scientific and common names |
| Lore/Story Text | Yes | All collectible lore entries |
| Battle Pass Names | Yes | All cosmetic item names |
| Voice Lines | Partial | Character callouts (P2 priority) |
| Marketing Materials | Yes | Store descriptions, trailers |
| Community Guidelines | Yes | All legal and policy text |


### 18.3 Cultural Considerations

Imagery: Some dinosaur-related imagery reviewed for cultural sensitivity

Symbols: Skull imagery limited in Chinese versions

Gestures: Emotes reviewed for cultural appropriateness

Colors: Colors adjusted for accessibility and cultural meaning

Formatting: Date/time/number formats localized per region


### 18.4 Localization Testing

UI Testing: All translated text reviewed for UI fit and overflow

Linguistic QA: Native speakers verify translation quality

Cultural QA: Region-specific testers check cultural appropriateness

Input Testing: Input method verification for CJK languages


## 19. Seasonal Content Plan

Each season runs 10 weeks with major content updates, new Battle Pass, and thematic changes to the island.


| Season | Theme | Major Additions |
|---|---|---|
| 1 | Welcome to the Park | Launch content, core map, 15 dinosaurs, base weapons |
| 2 | Deep Ocean | Underwater POI, aquatic dinosaurs (Mosasaurus, Plesiosaurus), diving gear, submarine |
| 3 | Ice Age | Frozen northern biome, Woolly Mammoth, Saber-tooth Tiger, snow storms, snowmobile |
| 4 | Facility Breach | Expanded underground lab, hybrid dinosaurs, new Indoraptor variants |
| 5 | Prehistoric Safari | African biome, new herbivores, safari-themed POIs, mounted dinosaur combat |
| 6 | Volcanic Eruption | Expanded volcanic zone, fire-themed dinosaurs, lava surfing, destruction events |


### 19.1 Season Structure


| Week | Content Drop |
|---|---|
| 1 | Season Launch: New Battle Pass, major map changes, new dinosaur |
| 2 | Quality of Life: Bug fixes, balance adjustments based on data |
| 3 | LTM Rotation: New Limited Time Mode introduced |
| 4 | Mid-Season: New weapon or equipment added |
| 5 | Community Event: Player challenges with exclusive rewards |
| 6 | LTM Rotation: Second Limited Time Mode |
| 7 | Content Update: New POI or map modification |
| 8 | Balance Patch: Major weapon and dinosaur adjustments |
| 9 | Finale Event: Story event, boss encounter, map teaser |
| 10 | Season End: Double XP, last chance for Battle Pass |


## 20. Art Direction & Visual Style


### 20.1 Visual Style Overview

Dino Royale uses a stylized semi-realistic art style that balances the wonder of dinosaurs with Roblox's aesthetic capabilities. The look is inspired by theme park attractions and adventure films, emphasizing vibrant colors, dramatic lighting, and sense of scale.


### 20.2 Color Palette


| Biome | Primary Colors | Accent Colors | Mood |
|---|---|---|---|
| Jungle | Deep greens, browns | Golden sunlight, red flowers | Mysterious, alive |
| Plains | Golden grass, blue sky | White clouds, orange sunset | Open, peaceful |
| Volcanic | Black rock, red lava | Orange glow, grey ash | Dangerous, dramatic |
| Swamp | Murky green, brown mud | Foggy white, purple flora | Eerie, mysterious |
| Coast | Blue water, tan sand | White foam, coral colors | Relaxing, tropical |
| Research | White sterile, grey metal | Red warning, blue screens | Clinical, abandoned |


### 20.3 Character Design Guidelines

Style: Roblox-compatible proportions with detailed textures

Dinosaurs: Mix of realistic proportions and stylized features

Player Outfits: Adventure/safari aesthetic with tactical elements

Weapons: Military-meets-theme-park visual language

Vehicles: Iconic designs referencing classic dinosaur media


### 20.4 Environmental Art Guidelines

Structures: Contrast between manicured park areas and overgrown wild zones

Vegetation: Dense, layered foliage creating natural cover and sightline breaks

Lighting: Dynamic, volumetric lighting emphasizing time of day and mood

Weather: Rain, fog, volcanic ash, and particle effects for atmosphere

Skybox: High-quality skybox with dynamic cloud movement


### 20.5 UI Art Style

Theme: Amber/fossil inspired with jungle green accents

Typography: Clean sans-serif with decorative headers

Icons: Rounded corners, organic shapes, leaf/bone motifs

Panels: Semi-transparent with blur effects

Highlights: Glowing amber, pulsing effects for interactions


### 20.6 Concept Art Placeholders

The following concept art pieces are required for production (to be created by art team):


| Category | Required Pieces | Priority |
|---|---|---|
| Characters | 5 base player models, 10 skin concepts | P0 |
| Dinosaurs | Full roster (11 species) model sheets | P0 |
| Weapons | All weapon categories concept art | P0 |
| Environments | 6 biome mood boards and key art | P0 |
| POIs | Detailed layouts for all 6 major POIs | P1 |
| Vehicles | All 6 vehicle designs | P1 |
| UI | Full UI kit mockups | P1 |
| Marketing | Key art, logo, promotional renders | P0 |


## Appendix A: Quick Reference Stats


### Player Statistics


| Stat | Value |
|---|---|
| Base Health | 100 HP |
| Max Shield | 100 |
| Move Speed (Walking) | 16 studs/sec |
| Move Speed (Sprinting) | 24 studs/sec |
| Crouch Speed | 8 studs/sec |
| Prone Speed | 4 studs/sec |
| Jump Height | 7 studs |
| Inventory Slots | 5 weapons + equipment |
| Revive Time | 5 seconds |
| Bleedout Time | 90 seconds |


### Damage Modifiers


| Hit Location | Multiplier |
|---|---|
| Headshot | 2.0x damage |
| Body | 1.0x damage |
| Limbs | 0.75x damage |


### Loot Spawn Rates by Location


| Location Type | Common | Uncommon | Rare | Epic | Legendary |
|---|---|---|---|---|---|
| Floor Loot | 45% | 30% | 18% | 6% | 1% |
| Chest | 30% | 35% | 25% | 8% | 2% |
| Supply Drop | 10% | 20% | 35% | 25% | 10% |
| Research Facility | 20% | 30% | 30% | 15% | 5% |
| Dinosaur Drop | Tier-based | - | - | - | Boss only |


### XP Rewards


| Action | XP Reward |
|---|---|
| Match Played | 50 XP |
| Survival per minute | 10 XP |
| Player Elimination | 50 XP |
| Dinosaur Kill (Common) | 10 XP |
| Dinosaur Kill (Rare) | 25 XP |
| Dinosaur Kill (Epic) | 50 XP |
| Dinosaur Kill (Legendary) | 100 XP |
| Top 25 | 100 XP |
| Top 10 | 200 XP |
| Top 5 | 300 XP |
| Victory Royale | 500 XP |
| First Win of Day | 1000 XP Bonus |


## Appendix B: Development Roadmap


### Phase 1: Pre-Production (Weeks 1-4)

Finalize game design document

Create art style guide and concept art

Prototype core movement and shooting mechanics

Design dinosaur AI behavior trees

Plan server architecture for 100 players

Establish localization pipeline

Define analytics requirements


### Phase 2: Core Development (Weeks 5-16)

Build map terrain and base biomes

Implement all weapon categories

Create dinosaur models and animations

Develop AI systems for all dinosaur tiers

Build matchmaking and lobby systems

Implement storm/circle system

Develop tutorial and onboarding flow

Implement social features (friends, parties, clans)


### Phase 3: Content & Polish (Weeks 17-24)

Build all POIs with detailed interiors

Add vehicles and equipment

Create Battle Pass reward track

Implement shop and monetization

Audio implementation and music

UI polish and accessibility features

Complete localization for P0 languages

Implement moderation and safety systems


### Phase 4: Testing & Launch (Weeks 25-30)

Closed alpha testing (Week 25-26)

Open beta testing (Week 27-28)

Bug fixes and balance adjustments

Performance optimization pass

Accessibility testing and refinement

Marketing push and influencer partnerships

Season 1 launch (Week 30)


### Post-Launch Support

Weekly bug fixes and balance patches

Bi-weekly LTM rotations

10-week seasonal content updates

Community feedback integration

Annual major map updates

Ongoing localization expansion

Continuous anti-cheat improvements

— End of Document —

Document Version 1.1 - Complete Edition

