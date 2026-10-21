local C={}
C.Souls={
 Graveyard={name="Wandering Soul",color={135,240,224}}, PumpkinPatch={name="Ember Soul",color={255,180,85}},
 HauntedForest={name="Verdant Soul",color={145,240,135}}, Swamp={name="Mire Soul",color={145,210,110}},
 Crypt={name="Ancient Soul",color={206,155,255}}, Briarwatch={name="Briar Soul",color={240,155,188}},
 Moonveil={name="Lunar Soul",color={155,195,255}}, Starfall={name="Stellar Soul",color={255,225,140}},
 Crownrest={name="Royal Soul",color={225,170,255}}, HollowCaverns={name="Crystal Soul",color={125,225,255}},
}
C.Weather={
 {id="Clear",name="Quiet Skies",weight=28,duration=0,color={160,210,255},effect="clear",mutation="Pure",value=1,chance=0},
 {id="Rain",name="Silver Rain",weight=12,duration=900,color={150,195,230},effect="rain",mutation="Dewkissed",value=1.25,chance=.18},
 {id="Storm",name="Spectral Thunderstorm",weight=6,duration=780,color={125,135,255},effect="storm",mutation="Charged",value=1.65,chance=.13},
 {id="Snow",name="Moonlit Snowfall",weight=9,duration=1020,color={210,235,255},effect="snow",mutation="Frosted",value=1.4,chance=.16},
 {id="Blizzard",name="Crystal Blizzard",weight=3,duration=720,color={180,220,255},effect="blizzard",mutation="Frozen",value=2,chance=.1},
 {id="Aurora",name="Spirit Aurora",weight=5,duration=900,color={100,255,195},effect="aurora",mutation="Auroral",value=1.8,chance=.14},
 {id="Meteor",name="Starlight Shower",weight=3,duration=720,color={255,215,140},effect="meteor",mutation="Starbound",value=2.2,chance=.09},
 {id="Golden",name="Golden Hour",weight=5,duration=900,color={255,210,110},effect="motes",mutation="Gilded",value=1.75,chance=.13},
 {id="Petals",name="Blossom Breeze",weight=8,duration=960,color={255,170,210},effect="petals",mutation="Blooming",value=1.35,chance=.2},
 {id="Fireflies",name="Firefly Festival",weight=7,duration=900,color={195,255,125},effect="fireflies",mutation="Luminous",value=1.45,chance=.18},
 {id="Fog",name="Pearlescent Mist",weight=9,duration=840,color={195,210,225},effect="fog",mutation="Veiled",value=1.3,chance=.18},
 {id="Eclipse",name="Violet Eclipse",weight=2,duration=600,color={175,115,255},effect="eclipse",mutation="Eclipsed",value=2.5,chance=.08},
 {id="Rainbow",name="Prismatic Rainbow",weight=3,duration=780,color={255,170,235},effect="rainbow",mutation="Prismatic",value=2,chance=.12},
 {id="Embers",name="Ember Winds",weight=6,duration=840,color={255,150,85},effect="embers",mutation="Smoldering",value=1.5,chance=.16},
 {id="Cosmic",name="Cosmic Tide",weight=2,duration=660,color={170,140,255},effect="cosmic",mutation="Astral",value=2.4,chance=.08},
 {id="Diamond",name="Diamond Dust",weight=4,duration=780,color={160,250,255},effect="crystals",mutation="Diamond",value=1.9,chance=.13},
 {id="Leaves",name="Autumn Drift",weight=8,duration=960,color={255,185,105},effect="leaves",mutation="Amber",value=1.35,chance=.2},
 {id="Moonbeams",name="Moonbeam Waltz",weight=4,duration=840,color={180,195,255},effect="moonbeams",mutation="Moonblessed",value=1.8,chance=.14},
 {id="SpiritTide",name="Great Spirit Migration",weight=2,duration=720,color={120,255,235},effect="spirits",mutation="Transcendent",value=3,chance=.06},
}
C.WeatherById={};C.Mutations={Pure={value=1,color={135,240,224}}}
for _,w in ipairs(C.Weather) do C.WeatherById[w.id]=w;C.Mutations[w.mutation]={value=w.value,color=w.color} end
C.Boosts={
 {id="RechargeTonic",name="Recharge Tonic",price=5000,duration=600,multiplier=1.5,desc="Selected graveyard recharges 50% faster for 10 minutes. Helps everyone in this server."},
 {id="SpiritFertilizer",name="Spirit Fertilizer",price=20000,duration=900,multiplier=2,desc="Selected graveyard recharges twice as fast for 15 minutes. Helps everyone in this server."},
 {id="MoonwellElixir",name="Moonwell Elixir",price=75000,duration=900,multiplier=3,desc="Selected graveyard recharges three times as fast for 15 minutes. Helps everyone in this server."},
}
C.BoostById={} for _,b in ipairs(C.Boosts) do C.BoostById[b.id]=b end
C.Badges={
 {id="FirstHarvest",name="First Harvest",stat="totalSouls",goal=100,reward=100},
 {id="SoulSeeker",name="Soul Seeker",stat="totalSouls",goal=2500,reward=750},
 {id="Gravekeeper",name="Gravekeeper",stat="totalSouls",goal=25000,reward=5000},
 {id="MasterRefiner",name="Master Refiner",stat="totalEssence",goal=10000,reward=1500},
 {id="WeatherWatcher",name="Weather Watcher",stat="mutatedSouls",goal=250,reward=1000},
}
return C

