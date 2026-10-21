-- Haunted Harvest shared config (safe to replicate: display values only).
-- The SERVER is always the authority; the client only uses this to draw UI.

local Config = {}
local GhostCatalog=require(script.Parent.GhostCatalog)

Config.GameName = "Haunted Harvest"
Config.StorageName = "Souls"   -- what you carry in your Soul Jar
Config.MoneyName = "Essence"   -- what you spend
Config.BaseJarCapacity = 100
Config.MaxReach = 18           -- studs, for NPC interactions
Config.HelperInterval = 2.2    -- seconds between helper pickups
Config.HelperRadius = 48       -- studs around the player a helper can reach
Config.HunterSteal = 0.25      -- fraction of souls a ghost hunter steals
Config.ShopReach = 45          -- studs, for buying upgrades

----------------------------------------------------------------------
-- Upgrades (bought with Essence at the Shop)
----------------------------------------------------------------------
Config.Upgrades = {
	{ id = "Refinement", name = "Soul Refinement", desc = "+20% Essence from every soul you convert", maxLevel = 15, baseCost = 220, growth = 1.6 },
	{ id = "GreedyHands", name = "Greedy Hands", desc = "+1 soul from every grave you drain", maxLevel = 10, baseCost = 350, growth = 1.8 },
	{ id = "SpectralBoots", name = "Spectral Boots", desc = "+2 movement speed per level. Sprint for an extra burst!", maxLevel = 20, baseCost = 150, growth = 1.32 },
	{ id = "Helpers", name = "Poltergeist Helper", desc = "A friendly ghost that follows you and drains nearby graves", maxLevel = 10, baseCost = 650, growth = 1.75 },
}
Config.UpgradeById = {}
for _, u in ipairs(Config.Upgrades) do
	Config.UpgradeById[u.id] = u
end

-- Cost to go from `level` to `level + 1` (nil when maxed)
function Config.upgradeCost(id, level)
	local u = Config.UpgradeById[id]
	if not u or level >= u.maxLevel then
		return nil
	end
	return math.floor(u.baseCost * u.growth ^ level)
end

function Config.jarCapacity(jarLevel)
	return Config.jarTier(jarLevel).capacity
end

function Config.essencePerSoul(refinementLevel)
	return 1 + 0.2 * refinementLevel
end

function Config.progressionMultiplier(data)
	local bonus=.15*(data.rebirths or 0)
	for _,def in ipairs(GhostCatalog.equipped(data)) do bonus+=def.bonus end
	local multiplier=1+bonus
	if data.vip then multiplier*=1.25 end
    if data.passes and data.passes.DoubleRefining then multiplier*=2 end
	if data.boosts and (data.boosts.EssenceBoost or 0)>os.time() then multiplier*=2 end
	return multiplier
end

function Config.storageFor(data)
	local id=data.equipment and data.equipment.storage
	if id==false then return nil end
	return Config.StorageById[id or Config.jarTier(data.upgrades.JarSize).id]
end
function Config.capacityFor(data)
	local storage=Config.storageFor(data);return storage and storage.capacity*((data.passes and data.passes.DoubleStorage) and 2 or 1) or 0
end

-- Purchased Essence remains separate so random eggs use earned currency only.
function Config.spendEssence(data,cost,earnedOnly)
 if type(cost)~="number" or cost<0 or cost~=cost then return false end
 local paid=math.clamp(data.paidEssence or 0,0,data.essence)
 if (earnedOnly and data.essence-paid or data.essence)<cost then return false end
 if not earnedOnly then data.paidEssence=paid-math.min(paid,cost) end
 data.essence-=cost;return true
end
function Config.combatMultiplier(data)
 return ((data.boosts and (data.boosts.BossBoost or 0)>os.time()) and 2 or 1)*((data.passes and data.passes.DoubleBoss) and 2 or 1)
end

function Config.walkSpeed(bootsLevel)
	return 16 + 2 * bootsLevel
end

----------------------------------------------------------------------
-- Realms (grave parts carry a Zone attribute)
----------------------------------------------------------------------
----------------------------------------------------------------------
-- Collecting tools: click to extract souls from graves in front of you.
-- range = studs, arc = degrees of the cone, cooldown = seconds, targets = souls
-- drained per swing, power = multiplier on each grave extraction.
----------------------------------------------------------------------
Config.Tools = {
	{id="GraveVacuum",kind="vacuum",name="Grave Vacuum",price=0,range=12,arc=120,cooldown=.9,targets=1,power=1,color={110,255,230},desc="Extracts souls from one grave. Hold click to keep absorbing."},
	{id="SpiritLantern",kind="vacuum",name="Spirit Lantern",price=450,range=16,arc=150,cooldown=.65,targets=1,power=1,color={255,200,110},desc="A faster collector. Absorbs one grave at a time."},
	{id="ReaperScythe",kind="vacuum",name="Reaper's Scythe",price=4000,range=19,arc=210,cooldown=.42,targets=1,power=1,color={190,110,255},desc="Rapid soul extraction from a single grave."},
	{id="SoulSiphon",kind="vacuum",name="Soul Siphon",price=18000,range=28,arc=360,cooldown=.25,targets=1,power=1,color={120,255,160},desc="A focused siphon with rapid single-grave absorption."},
	{id="RustySpade",kind="dig",name="Rusty Spade",price=220,range=7,arc=360,cooldown=1.4,targets=1,power=1,color={200,170,120},desc="Extracts one grave. Hold click to keep digging."},
	{id="SilverShovel",kind="dig",name="Silver Shovel",price=4500,range=8,arc=360,cooldown=.85,targets=1,power=1,color={200,220,255},desc="Digs the same grave faster than a rusty spade."},
	{id="NecroSpade",kind="dig",name="Necro Spade",price=30000,range=9,arc=360,cooldown=.45,targets=1,power=1,color={170,255,150},desc="A swift spade that extracts one grave at a time."},
	{id="EctoplasmCondenser",kind="vacuum",name="Ectoplasm Condenser",price=60000,range=30,arc=360,cooldown=0.21,targets=1,power=1,requiresTool="SoulSiphon",color={90,225,255},desc="Faster single-grave absorption. Requires Soul Siphon."},
	{id="AstralHarvester",kind="vacuum",name="Astral Harvester",price=180000,range=32,arc=360,cooldown=0.18,targets=1,power=1,requiresTool="EctoplasmCondenser",color={160,155,255},desc="Faster single-grave absorption. Requires Ectoplasm Condenser."},
	{id="EclipseEngine",kind="vacuum",name="Eclipse Engine",price=550000,range=34,arc=360,cooldown=0.15,targets=1,power=1,requiresTool="AstralHarvester",color={255,130,95},desc="Faster single-grave absorption. Requires Astral Harvester."},
	{id="SovereignReaper",kind="vacuum",name="Sovereign Reaper",price=1500000,range=36,arc=360,cooldown=0.12,targets=1,power=1,requiresTool="EclipseEngine",color={255,220,120},desc="Faster single-grave absorption. Requires Eclipse Engine."},
	{id="CrystalExcavator",kind="dig",name="Crystal Excavator",price=100000,range=10,arc=360,cooldown=0.32,targets=1,power=1,requiresTool="NecroSpade",color={100,230,255},desc="Faster single-grave digging. Requires Necro Spade."},
	{id="RoyalGravedigger",kind="dig",name="Royal Gravedigger",price=400000,range=12,arc=360,cooldown=0.22,targets=1,power=1,requiresTool="CrystalExcavator",color={255,205,110},desc="Faster single-grave digging. Requires Crystal Excavator."},
}
-- Soul reserves grow along the expedition route; refill time is from empty.
Config.GraveTiers = {
	Graveyard={capacity=60,reward=5,refillSeconds=180},
	PumpkinPatch={capacity=140,reward=9,refillSeconds=240},
	HauntedForest={capacity=260,reward=14,refillSeconds=300},
	Swamp={capacity=420,reward=22,refillSeconds=360},
	Crypt={capacity=650,reward=30,refillSeconds=420},
	Moonveil={capacity=950,reward=34,refillSeconds=480},
	Briarwatch={capacity=1400,reward=38,refillSeconds=540},
	HollowCaverns={capacity=2000,reward=42,refillSeconds=600},
	Starfall={capacity=2800,reward=46,refillSeconds=720},
	Crownrest={capacity=4000,reward=50,refillSeconds=900},
}
Config.GraveProgression = {"Graveyard","PumpkinPatch","HauntedForest","Swamp","Crypt","Moonveil","Briarwatch","HollowCaverns","Starfall","Crownrest"}
Config.DigRegrow = 45 -- seconds before a dug grave holds souls again
table.sort(Config.Tools,function(a,b)
 if a.kind~=b.kind then return a.kind=="vacuum" end
 return a.price<b.price
end)
Config.ToolById = {}
for _, t in ipairs(Config.Tools) do
	Config.ToolById[t.id] = t
end

-- named tiers for the container that holds your souls
Config.ShopName = "Spirit Emporium"
Config.JarTiers = {
	{ id = "ClayJar", level = 0, name = "Clay Jar", capacity = 100, price = 0, desc = "A humble jar. Every ghost starts with one." },
	{ id = "GlassJar", level = 3, name = "Glass Jar", capacity = 300, price = 400, desc = "Holds 3x the souls. Needed for the Pumpkin Patch." },
	{ id = "LanternJar", level = 6, name = "Lantern Jar", capacity = 800, price = 2000, desc = "A caged lantern jar. Needed for the Haunted Forest." },
	{ id = "CrystalVessel", level = 10, name = "Crystal Vessel", capacity = 2000, price = 8500, desc = "Enchanted crystal. Needed for the Whispering Swamp." },
	{ id = "VoidUrn", level = 15, name = "Void Urn", capacity = 5000, price = 35000, desc = "Holds a sliver of the void. Needed for the Sunken Crypt." },
	{ id = "AbyssCoffin", level = 20, name = "Abyss Coffin", capacity = 12000, price = 120000, desc = "A reinforced coffin for long graveyard expeditions." },
	{id="MoonstoneReliquary",level=25,name="Moonstone Reliquary",capacity=24000,price=220000,requiresStorage="AbyssCoffin",desc="Holds 24,000 souls. Requires Abyss Coffin."},
	{id="AstralReservoir",level=30,name="Astral Reservoir",capacity=50000,price=650000,requiresStorage="MoonstoneReliquary",desc="Holds 50,000 souls. Requires Moonstone Reliquary."},
	{id="EclipseReactor",level=35,name="Eclipse Reactor",capacity=100000,price=1800000,requiresStorage="AstralReservoir",desc="Holds 100,000 souls. Requires Astral Reservoir."},
	{id="SovereignVault",level=40,name="Sovereign Vault",capacity=200000,price=5000000,requiresStorage="EclipseReactor",desc="Holds 200,000 souls. Requires Eclipse Reactor."},
}
Config.StorageById = {}
for _, t in ipairs(Config.JarTiers) do
	Config.StorageById[t.id] = t
end
function Config.jarTier(jarLevel)
	local best = Config.JarTiers[1]
	for _, t in ipairs(Config.JarTiers) do
		if jarLevel >= t.level then best = t end
	end
	return best
end

----------------------------------------------------------------------
-- Bosses: one rises every few minutes; each area's boss is stronger than the last.
-- Hit them with any tool. Everyone who deals damage shares the reward.
----------------------------------------------------------------------
Config.BossFirstDelay = 60    -- seconds after the server starts
Config.BossInterval = 240     -- seconds between bosses
Config.BossLifetime = 240     -- seconds before an unbeaten boss retreats
Config.BossToolDamage = 12    -- base damage per tool hit (multiplied by the tool's power)
Config.Bosses = {
	{ id="CavernKeeper",zone="HollowCaverns",name="The Crystal Keeper",tier=3,center={0,-660},floorY=9.7,radius=17,
	hp=4200,damage=16,speed=7,scale=1.6,reward={essence=1800,souls=350},attacks={bolts=true} },
	{ id = "GraveWarden", zone = "Graveyard", name = "The Grave Warden", tier = 1, center = { 22, -45 }, radius = 30,
		hp = 500, damage = 9, speed = 10, scale = 2.6, reward = { essence = 150, souls = 40 }, attacks = { slam = true } },
	{ id = "HarvestKing", zone = "PumpkinPatch", name = "Jack, the Harvest King", tier = 2, center = { 120, 14 }, radius = 32,
		hp = 1400, damage = 14, speed = 11, scale = 2.9, reward = { essence = 500, souls = 120 }, attacks = { slam = true, bolts = true } },
	{ id = "HollowTreant", zone = "HauntedForest", name = "The Hollow Treant", tier = 3, center = { -122, 14 }, radius = 34,
		hp = 3500, damage = 20, speed = 10, scale = 3.3, reward = { essence = 1500, souls = 300 }, attacks = { slam = true, bolts = true } },
	{ id = "MireHag", zone = "Swamp", name = "The Mire Hag", tier = 4, center = { -122, -125 }, radius = 34,
		hp = 7500, damage = 27, speed = 12, scale = 3.0, reward = { essence = 4000, souls = 700 }, attacks = { slam = true, bolts = true, storm = true } },
	{ id = "LichKing", zone = "Crypt", name = "The Lich King", tier = 5, center = { 0, -172 }, radius = 30,
		hp = 15000, damage = 36, speed = 12, scale = 3.5, reward = { essence = 12000, souls = 1500 }, attacks = { slam = true, bolts = true, storm = true } },
}
Config.BossById = {}
for _, b in ipairs(Config.Bosses) do
	Config.BossById[b.id] = b
end

Config.Zones = {
	Graveyard = { label = "Graveyard" },
	Wilds = { label = "Forgotten Wilds" },
	HollowCaverns = { label = "Hollow Caverns" },
	PumpkinPatch = { label = "Pumpkin Patch", requires = { jar = 3 } },
	HauntedForest = { label = "Haunted Forest", requires = { jar = 6, quest = "pumpkin_patrol" } },
	Swamp = { label = "Whispering Swamp", requires = { jar = 10, helpers = 2 } },
	Crypt = { label = "Sunken Crypt", requires = { jar = 15, quest = "swamp_souls", pay = 5000 } },
}
-- gate order: each one is a bit in the collision mask, so keep this stable
Config.ZoneOrder = { "PumpkinPatch", "HauntedForest", "Swamp", "Crypt" }

----------------------------------------------------------------------
-- NPCs
----------------------------------------------------------------------
Config.Npcs = {
	Morty = {
		name = "Morty the Gravekeeper",
		idle = "Quiet night, little ghost. Come back if you need work.",
		locked = "I've nothing for you yet. Keep collecting and growing that jar.",
	},
	Vex = {
		name = "Madame Vex",
		idle = "My cauldron is full for now, darling. Visit again later.",
		locked = "Prove yourself to Morty first, then we'll talk, dearie.",
	},
	Gourd = {
		name = "Sir Gourdington",
		idle = "The patch is at peace. Thank you, brave spirit!",
		locked = "Eh? A tiny ghost like you? Learn the ropes from Morty first.",
	},
	Fern = {
		name = "Fern the Hermit",
		idle = "The trees whisper your name now. That's all I have for you.",
		locked = "The forest is not ready to trust you. Do some jobs in the village.",
	},
	Bog = {
		name = "Old Bog",
		idle = "The swamp keeps its secrets. For now.",
		locked = "Come back when the forest knows you. *glub*",
	},
	Bones = {
		name = "Sir Bones",
		idle = "The crypt is quiet. You have done well, champion.",
		locked = "Only swamp-wanderers may enter my crypt. Go on, prove yourself.",
	},
}

----------------------------------------------------------------------
-- Quests (one active at a time). kind: collect | earn | buy
-- zone (optional) restricts "collect" quests to a realm.
----------------------------------------------------------------------
Config.Quests = {
	{ id = "first_harvest", npc = "Morty", title = "First Harvest", desc = "Collect 25 souls", kind = "collect", goal = 25, reward = 40,
		intro = "Ah, a fresh little ghost! Equip your Grave Vacuum (press 1), aim at a glowing grave and click to pull its souls out. Gather 25 and I'll make it worth your while.",
		progressText = "Aim your Grave Vacuum at the glowing graves in the cemetery and click.",
		doneText = "That's a fine haul! Here, take this Essence for your trouble." },
	{ id = "first_refine", npc = "Morty", title = "Soul to Essence", desc = "Convert souls into 60 Essence", kind = "earn", goal = 60, reward = 80, requires = "first_harvest",
		intro = "Souls are worthless in a jar. Press Convert near your Spirit Roost to refine them into Essence. Make 60.",
		progressText = "Return to your own Spirit Roost and press Convert to refine souls into Essence.",
		doneText = "You're a natural! Essence is how the dead do business." },
	{ id = "shopper", npc = "Morty", title = "Upgrade Time", desc = "Buy 2 things at the Spirit Emporium", kind = "buy", goal = 2, reward = 150, requires = "first_refine",
		intro = "Spend that Essence at the Spirit Emporium! Buy any 2 things (tools, storage or upgrades) and your whole career changes.",
		progressText = "Visit the Spirit Emporium west of the spawn. Try a new tool or a Glass Jar!",
		doneText = "Now THAT is how you grow. The wider world is open to you." },
	{ id = "brew_supplies", npc = "Vex", title = "Cauldron Supplies", desc = "Collect 150 souls", kind = "collect", goal = 150, reward = 220, requires = "shopper",
		intro = "My brews eat souls, dearie! Bring me 150 fresh ones and I'll pay in Essence.",
		progressText = "More souls, dearie. The cauldron is hungry.",
		doneText = "Delicious. The cauldron purrs. Here's your Essence, sweet thing." },
	{ id = "pumpkin_patrol", npc = "Gourd", title = "Pumpkin Patrol", desc = "Collect 250 souls in the Pumpkin Patch", kind = "collect", zone = "PumpkinPatch", goal = 250, reward = 300, requires = "shopper",
		intro = "Mischievous spirits are loose in my pumpkin patch! Gather 250 of them. You'll need a Glass Jar to get through the gate.",
		progressText = "The orange spirits hide among the pumpkins. Keep hunting!",
		doneText = "Huzzah! The patch is saved. A hero's reward for you!" },
	{ id = "forest_walk", npc = "Fern", title = "Whispers in the Woods", desc = "Collect 600 souls in the Haunted Forest", kind = "collect", zone = "HauntedForest", goal = 600, reward = 500, requires = "pumpkin_patrol",
		intro = "The old trees hold lonely souls. Gather 600 for me. You'll need a Lantern Jar and Sir Gourdington's trust to pass the gate.",
		progressText = "Listen for the glow between the trunks, little one.",
		doneText = "They rest easier now. Take this, with the forest's thanks." },
	{ id = "swamp_souls", npc = "Bog", title = "Bog Business", desc = "Collect 1200 souls in the Whispering Swamp", kind = "collect", zone = "Swamp", goal = 1200, reward = 1100, requires = "forest_walk",
		intro = "Glub... the swamp is thick with souls. Fetch 1200. You'll need a Crystal Vessel and two Poltergeist Helpers to get in.",
		progressText = "Watch the water. The glowing ones are the good ones. *glub*",
		doneText = "Glub glub! Fine work. Take your Essence." },
	{ id = "crypt_clear", npc = "Bones", title = "Crypt Champion", desc = "Collect 2500 souls in the Sunken Crypt", kind = "collect", zone = "Crypt", goal = 2500, reward = 2500, requires = "swamp_souls",
		intro = "My crypt holds the richest souls of all. Gather 2500. Only those carrying a Void Urn who pay the toll may enter.",
		progressText = "The deepest chambers glow brightest. Be bold!",
		doneText = "Magnificent! You are a true Haunted Harvester!" },
	{ id = "bigger_jar", npc = "Morty", title = "Bigger Jar", desc = "Buy a Glass Jar at the Spirit Emporium", kind = "reach", goal = 3, reward = 220, requires = "shopper",
		intro = "That clay jar won't hold much. Buy a Glass Jar at the Spirit Emporium and you'll carry three times as many souls.",
		progressText = "The Spirit Emporium sells better storage. Look for the Glass Jar.",
		doneText = "Look at the size of that jar! The pumpkin fields will welcome you now." },
	{ id = "grave_robber", npc = "Morty", title = "Graveyard Regular", desc = "Collect 300 souls", kind = "collect", goal = 300, reward = 450, requires = "bigger_jar",
		intro = "Now that you can carry more, let's put it to use. Gather 300 souls from anywhere you like.",
		progressText = "Keep harvesting. And when a boss rises, fight it for a big reward!",
		doneText = "Three hundred souls! You're a proper Harvester now." },
	{ id = "potion_money", npc = "Vex", title = "Potion Money", desc = "Convert souls into 800 Essence", kind = "earn", goal = 800, reward = 500, requires = "brew_supplies",
		intro = "My customers pay well, but only in Essence. Refine 800 Essence worth of souls and I'll share the profit.",
		progressText = "Press Convert near your Spirit Roost to refine souls. Refinement upgrades help a lot!",
		doneText = "Ka-ching! The cauldron and I thank you." },
	{ id = "ghostly_help", npc = "Vex", title = "A Little Help", desc = "Own 2 Poltergeist Helpers", kind = "helpers", goal = 2, reward = 600, requires = "potion_money",
		intro = "Even a witch needs helpers. Buy 2 Poltergeist Helpers at the Shop and they'll collect souls for you.",
		progressText = "The Shop sells Poltergeist Helpers. They follow you around and gather souls.",
		doneText = "What lovely little ghosts! Take this, dearie." },
	{ id = "jack_lights", npc = "Gourd", title = "Jack of Lanterns", desc = "Collect 700 souls in the Pumpkin Patch", kind = "collect", zone = "PumpkinPatch", goal = 700, reward = 700, requires = "pumpkin_patrol",
		intro = "More mischief in the patch! Gather 700 more of the orange spirits and I'll make you an honorary scarecrow.",
		progressText = "They hide between the pumpkin rows. Keep hunting!",
		doneText = "Honorary scarecrow it is! Here's your reward." },
	{ id = "mushroom_hunt", npc = "Fern", title = "Glow Mushroom Gathering", desc = "Collect 1500 souls in the Haunted Forest", kind = "collect", zone = "HauntedForest", goal = 1500, reward = 1100, requires = "forest_walk",
		intro = "The glowing mushrooms feed on lonely souls. Help me gather 1500 so they may rest.",
		progressText = "Follow the glowing mushrooms deeper into the woods.",
		doneText = "The forest sings your name tonight. Thank you." },
	{ id = "deep_water", npc = "Bog", title = "Deep Water Jar", desc = "Get a Crystal Vessel", kind = "reach", goal = 10, reward = 2000, requires = "swamp_souls",
		intro = "Glub... deep souls need strong storage. Get a Crystal Vessel and you'll be ready. *glub*",
		progressText = "The Spirit Emporium sells Crystal Vessels. Save up!",
		doneText = "A jar fit for the crypt. Go on, glub." },
	{ id = "crypt_master", npc = "Bones", title = "Crypt Master", desc = "Collect 8000 souls in the Sunken Crypt", kind = "collect", zone = "Crypt", goal = 8000, reward = 6000, requires = "crypt_clear",
		intro = "The deepest souls are the most valuable. Collect 8000 of them and the crypt is yours.",
		progressText = "Brave the avenue of pillars. The richest grave souls glow violet.",
		doneText = "The crypt bows to you, Master of Souls." },
	{ id = "ghost_army", npc = "Bones", title = "Army of Ghosts", desc = "Own 6 Poltergeist Helpers", kind = "helpers", goal = 6, reward = 8000, requires = "crypt_master",
		intro = "A true champion commands an army. Own 6 Poltergeist Helpers and I'll reward you handsomely.",
		progressText = "Buy more Poltergeist Helpers at the Shop. Their numbers are your strength.",
		doneText = "An army of spirits at your command. The Haunted Harvest is yours!" },
}
require(script.Parent.ExpansionConfig)(Config)

for _,q in ipairs(Config.Quests) do
	q.eggReward=q.zone=="HollowCaverns" and "CavernEgg" or (q.zone=="Moonveil" or q.zone=="Briarwatch" or q.zone=="Starfall" or q.zone=="Crownrest") and "HighlandEgg" or "LanternEgg"
end
Config.QuestById = {}
Config.QuestsByNpc = {}
for _, q in ipairs(Config.Quests) do
	Config.QuestById[q.id] = q
	Config.QuestsByNpc[q.npc] = Config.QuestsByNpc[q.npc] or {}
	table.insert(Config.QuestsByNpc[q.npc], q)
end

local startingScale=workspace:GetAttribute("StartingAreaScale") or 1
for _,boss in ipairs(Config.Bosses) do if boss.zone~="HollowCaverns" then boss.center={boss.center[1]*startingScale,boss.center[2]*startingScale};boss.radius*=startingScale end end
return Config
