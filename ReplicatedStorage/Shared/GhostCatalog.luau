local Catalog={}
Catalog.Pets={
 {id="LanternWisp",name="Lantern Wisp",price=500,bonus=.05,power=1,refine=4,bossDamage=0,rarity="Common",color={125,235,218},desc="Helps gather graves and refines 4 extra souls each second."},
 {id="MossSprite",name="Moss Sprite",price=2500,bonus=.10,power=2,refine=7,bossDamage=0,rarity="Uncommon",color={150,240,125},desc="A patient collector that speeds up soul refining."},
 {id="CrystalSpirit",name="Crystal Spirit",price=10000,bonus=.20,power=4,refine=15,bossDamage=6,rarity="Rare",color={175,160,255},desc="A powerful refiner that also attacks nearby bosses."},
 {id="GuardianGhost",name="Guardian Ghost",price=1800,bonus=0,power=0,refine=2,bossDamage=12,rarity="Uncommon",color={255,202,127},desc="A brave companion that attacks a boss every 3 seconds."},
 {id="SpectralKnight",name="Spectral Knight",price=14000,bonus=.05,power=0,refine=5,bossDamage=28,rarity="Rare",color={150,200,255},desc="Protects its hunter with strong attacks against bosses."},
 {id="RoyalPhantom",name="Royal Phantom",price=0,bonus=.25,power=3,refine=24,bossDamage=20,rarity="Legendary",color={245,172,255},desc="Found in eggs: an exceptional refiner and boss companion."},
}
Catalog.ById={} for _,p in ipairs(Catalog.Pets) do Catalog.ById[p.id]=p end
Catalog.Eggs={
 {id="LanternEgg",name="Lantern Ghost Egg",price=750,outcomes={{"LanternWisp",55},{"MossSprite",25},{"GuardianGhost",15},{"CrystalSpirit",5}}},
 {id="HighlandEgg",name="Highland Ghost Egg",price=4000,outcomes={{"MossSprite",40},{"GuardianGhost",30},{"CrystalSpirit",20},{"SpectralKnight",9},{"RoyalPhantom",1}}},
 {id="CavernEgg",name="Crystal Ghost Egg",price=12000,outcomes={{"CrystalSpirit",50},{"SpectralKnight",35},{"RoyalPhantom",15}}},
}
Catalog.EggById={} for _,egg in ipairs(Catalog.Eggs) do Catalog.EggById[egg.id]=egg end
Catalog.Foods={
 {id="SpiritTreat",name="Spirit Treat",price=200,xp=50},
 {id="Moonberry",name="Moonberry",price=1500,xp=500},
 {id="StarBiscuit",name="Star Biscuit",price=10000,xp=4000},
}
Catalog.FoodById={} for _,f in ipairs(Catalog.Foods) do Catalog.FoodById[f.id]=f end
function Catalog.xpToLevel(level) return math.floor(100*level^1.6) end
function Catalog.stats(pet)
 local base=Catalog.ById[pet.kind];if not base then return nil end
 local def=table.clone(base);local level=math.clamp(math.floor(pet.level or 1),1,20);local multiplier=1+.1*(level-1)
 def.level=level;def.refine=math.floor(base.refine*multiplier);def.bossDamage=math.floor(base.bossDamage*multiplier);def.power=math.floor(base.power*multiplier);def.bonus=base.bonus*multiplier;return def
end
function Catalog.addXP(pet,xp)
 pet.level=math.clamp(math.floor(pet.level or 1),1,20);pet.xp=math.max(0,pet.xp or 0)+math.max(0,xp)
 while pet.level<20 and pet.xp>=Catalog.xpToLevel(pet.level) do pet.xp-=Catalog.xpToLevel(pet.level);pet.level+=1 end
 if pet.level>=20 then pet.xp=0 end
end
function Catalog.equipped(data)
 local result={};local pets=data.pets;if not pets then return result end
 local owned={} for _,pet in ipairs(pets.inventory or {}) do owned[pet.uid]=pet end
 for _,uid in ipairs(pets.equipped or {}) do local pet=owned[uid];local def=pet and Catalog.ById[pet.kind];if def then table.insert(result,Catalog.stats(pet)) end end
 return result
end
function Catalog.refineRate(data)
 local rate=8 for _,def in ipairs(Catalog.equipped(data)) do rate+=def.refine end
 if (data.boosts and (data.boosts.RefineBoost or 0)>os.time()) then rate*=2 end
 if data.passes and data.passes.DoubleRefining then rate*=2 end
 return rate
end
function Catalog.maxEquipped(data) return (data.passes and data.passes.GhostSlots) and 5 or 3 end
return Catalog

