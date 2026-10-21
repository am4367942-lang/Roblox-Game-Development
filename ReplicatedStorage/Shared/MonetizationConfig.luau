local C={
 VIP={key="VIP",id=2037296328,name="VIP",kind="pass",description="Permanent +25% refining Essence and a VIP badge."},
 Products={
  {key="EssenceBoost",id=3718527871,name="2× Essence",kind="boost",duration=900,description="Double refining Essence for 15 minutes."},
  {key="RefineBoost",id=3718528090,name="2× Refining Speed",kind="boost",duration=900,description="Refine souls twice as fast for 15 minutes."},
  {key="BossBoost",id=3718528321,name="2× Boss Damage",kind="boost",duration=900,description="Double your collector and ghost boss damage for 15 minutes."},
  {key="EssenceSmall",id=3718528592,name="1,000 Essence",kind="essence",amount=1000,description="1,000 Essence for tools, storage and upgrades. Cannot buy random eggs."},
  {key="EssenceLarge",id=3718528894,name="10,000 Essence",kind="essence",amount=10000,description="10,000 Essence for tools, storage and upgrades. Cannot buy random eggs."},
  {key="SoulsSmall",id=3718529069,name="500 Banked Souls",kind="souls",amount=500,description="500 souls stored safely in your bank. Transfer to your jar to refine at your Spirit Roost."},
  {key="SoulsLarge",id=3718553388,name="5,000 Banked Souls",kind="souls",amount=5000,description="5,000 souls stored safely in your bank. Transfer to your jar to refine at your Spirit Roost."},
 }
}
C.Passes={C.VIP,
 {key="DoubleRefining",id=2036666378,name="2× Refining + Essence",kind="pass",description="Permanently doubles refining speed AND refining Essence. Stacks with timed boosts and VIP."},
 {key="DoubleBoss",id=2038352360,name="2× Boss Damage",kind="pass",description="Permanently doubles damage from your tools and equipped ghosts against bosses."},
 {key="GhostSlots",id=2037446385,name="+2 Equipped Ghosts",kind="pass",description="Permanently equip 5 ghosts instead of 3. Includes collecting, refining and boss companions."},
 {key="DoubleStorage",id=2036582469,name="2× Soul Storage",kind="pass",description="Permanently doubles the capacity of every equipped storage jar."},
}
return C
