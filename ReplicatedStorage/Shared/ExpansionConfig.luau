-- Additional regions do not join ZoneOrder: its collision masks belong to the original gates.
return function(Config)
	local regions={
		{id="Moonveil",label="Moonveil Memorial",hunters={{"Hale","Captain Hale"},{"Mira","Wisp Researcher Mira"}}},
		{id="Briarwatch",label="Briarwatch Heights",hunters={{"Rowan","Ranger Rowan"},{"Flint","Relic Hunter Flint"}}},
		{id="Starfall",label="Starfall Necropolis",hunters={{"Lyra","Astral Hunter Lyra"},{"Gale","Trailkeeper Gale"}}},
		{id="Crownrest",label="Crownrest Summit",hunters={{"Orion","Commander Orion"},{"Echo","Spirit Listener Echo"}}},
	}
	local titles={
		{"First Watch","Lantern Patrol","The Restless Rows","Guardian of Moonveil"},
		{"Listening to Wisps","Memory Gathering","A Gentle Release","Moonveil Research"},
		{"Up the Old Trail","Briarwatch Patrol","Souls in the Stone","Keeper of the Heights"},
		{"Buried Stories","Relic Recovery","The Forgotten Guard","Briarwatch Expedition"},
		{"Falling Starlight","Astral Survey","Celestial Echoes","Guardian of Starfall"},
		{"Wayfinder Duty","Lighting the Trail","The Long Watch","Starfall Sanctuary"},
		{"Summit Initiation","Crownrest Patrol","The Royal Vigil","Highland Commander"},
		{"Hear the Mountain","Quiet Voices","The Last Refrain","Harmony of the Summit"},
	}
	local hunterIndex=0
	for regionIndex,r in ipairs(regions) do
		Config.Zones[r.id]={label=r.label}
		for _,hunter in ipairs(r.hunters) do
			hunterIndex+=1
			local id,name=hunter[1],hunter[2]
			Config.Npcs[id]={name=name,idle="The grave wisps are peaceful for now. Thank you for your help.",locked="Finish my previous assignment first."}
			local previous=nil
			for step=1,4 do
				local goal=({250,650,1500,3500})[step]*regionIndex
				local qid=string.lower(id).."_watch_"..step
				local title=titles[hunterIndex][step]
				local kind, zone = "collect", r.id
				local desc=("Collect %d souls in %s"):format(goal,r.label)
				local intro=("%s needs your help. Extract %d souls from the graves here. Equip a collector or spade and click beside a glowing grave. Reserves recover slowly; move between rows."):format(r.label,goal)
				local progressText="Keep collecting in "..r.label..". Return to your own Spirit Roost and press Convert when your jar is full."
				if step==3 then
					kind="earn";zone=nil;title="Roost Refinery: "..title
					desc=("Earn %d Essence by converting souls"):format(goal)
					intro=("Our field equipment needs fuel. Earn %d Essence by converting souls at your own Spirit Roost."):format(goal)
					progressText="Collect souls, return to your own Spirit Roost, and press Convert."
				elseif step==2 and hunterIndex%2==0 then
					kind="helpers";zone=nil;goal=regionIndex;title="Recruit a Spirit Team"
					desc=("Own %d Poltergeist Helper%s"):format(goal,goal==1 and "" or "s")
					intro="A good hunter brings a spirit team. Recruit "..goal.." Poltergeist Helpers from the Spirit Emporium."
					progressText="Buy Poltergeist Helpers at the Spirit Emporium. Helpers you already own count."
				end
				table.insert(Config.Quests,{
					id=qid,npc=id,title=title,kind=kind,zone=zone,goal=goal,
					reward=kind=="helpers" and regionIndex*350 or math.floor(goal*(.45+step*.1)),requires=previous,
					desc=desc,
					intro=intro,
					progressText=progressText,
					doneText="Excellent work. Here is your Essence reward. I have more patrol work when you are ready.",
				})
				previous=qid
			end
		end
	end
	Config.Npcs.Sable={name="Cavern Keeper Sable",idle="The crystal graves are resting. Let their light return.",locked="Finish my current survey first."}
	local previous=nil
	for i,goal in ipairs({600,1400,3000,6500}) do
		local id="sable_cavern_"..i
		table.insert(Config.Quests,{id=id,npc="Sable",title=({"A Light Below","Crystal Echoes","The Keeper's Vigil","Hollow Sanctuary"})[i],
			kind="collect",zone="HollowCaverns",goal=goal,reward=math.floor(goal*.9),requires=previous,
			desc="Extract "..goal.." souls in Hollow Caverns",
			intro="These crystal graves hold the mountain's oldest memories. Extract "..goal.." souls here. Let emptied graves recharge while you visit another row.",
			progressText="Keep collecting from the glowing cave graves.",doneText="The cavern remembers your kindness. Take this Essence for your next expedition."})
		previous=id
	end
end
