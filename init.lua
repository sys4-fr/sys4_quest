local S
if minetest.get_modpath("intllib") then
  S = intllib.Getter()
else
  S = function(s) return s end
end

if not minetest.get_modpath("sys4_achievements") or not minetest.get_modpath("awards") then return end

sys4_quest = {}

function sys4_quest.getQuestIndex(questname)
   for i=1, #sys4_quest.quests do
      local quest = sys4_quest.quests[i][1]
      if quest == questname then
	 return i
      end
   end

   return nil
end

function sys4_quest.next_quest(playername, questname)

   if questname ~= "" then
      local quest = string.split(questname, ":")[2]
      if quest and quest ~= nil and quest ~= "" and sys4_quest.hasDependencies(quest) then
	 local nextQuest = nil
	 for name,award in pairs(awards.def) do
	    local award_req = award.award_req
	    
	    if award_req and award_req ~= nil and award_req == quest then
	       nextQuest = sys4_quest.getQuestIndex(name)
	       sys4_quest.current_quest[playername] = nextQuest
	       minetest.after(1, function() quests.start_quest(playername, "sys4_quest:"..name) end)
	    end
	 end

	 if nextQuest == nil then
	    return
	 end
      end
   end
end

function sys4_quest.hasDependencies(award_name)
   for name, award in pairs(awards.def) do
      local award_req = award.award_req

      if award_req and award_req ~= nil and award_req == award_name then
	 return true
      end
   end
   
   return false
end

-- Make Quests from sys4 achievements. Not included secret and original awards from awards mod except 'award_mesefind'
function sys4_quest.make_initial_quests()
   local i = 1
   local initialQuests = {}

   for name, award in pairs(awards.def) do
      if not award.secret
	 and (
	    string.split(name, "_")[1] ~= "award"
	       or (
		  sys4_achievements.awards ~= "sys4"
		     and name == "award_mesefind"
	       )
	       or (
		  sys4_achievements.awards == "sys4"
		     and (
			name == "award_lumberjack"
			   or name == "award_junglebaby"
			   or name == "award_youre_winner"
			   or name == "award_mine2"
			   or name == "award_marchand_de_sable"
		     )
	       )
	 )
      then
	 table.insert(initialQuests, i, {
			 name,
			 award.title,
			 award.trigger.target,
			 award.description,
			 sys4_quest.hasDependencies(name)
					})
	 i = i + 1
      end
   end
   
   return initialQuests
end

function sys4_quest.isInSameGroup(node1, node2, quest)
   local items = {}
   local mod = ""

   if node1 == 'default:tree'
      and ( quest == "award_lumberjack"
	       or quest == "award_lumberjack_semipro"
	       or quest == "award_lumberjack_professional"
	       or quest == "award_lumberjack_leet")
   then
      mod = 'default'
      items = {'tree', 'pine_tree', 'acacia_tree'}

   elseif node1 == 'default:tree' then
      mod = 'default'
      items = {'tree', 'pine_tree', 'acacia_tree', 'jungletree'}

   elseif node1 == 'default:leaves' then
      mod = 'default'
      items = {'leaves', 'jungleleaves', 'pine_needles', 'acacia_leaves'}

   elseif node1 == 'default:sand' then
      mod = 'default'
      items = {'sand', 'desert_sand'}

   elseif node1 == 'default:snow' then
      mod = 'default'
      items = {'snow', 'snowblock'}

   elseif node1 == 'default:stone' then
      mod = 'default'
      items = {'stone', 'desert_stone', 'cobble', 'desert_cobble', 'mossycobble'}

   elseif node1 == 'default:wood' then
      mod = 'default'
      items = {'wood', 'junglewood', 'pine_wood', 'acacia_wood'}

   elseif node1 == 'default:cobble' then
      mod = 'default'
      items = {'cobble', 'desert_cobble'}

   elseif node1 == 'default:stonebrick' then
      mod = 'default'
      items = {'stonebrick', 'desert_stonebrick'}

   elseif node1 == 'dye:black' then
      mod = "dye"
      items = {'red', 'blue', 'yellow', 'white', 'orange', 'violet', 'black'}

   elseif node1 == 'wool:black' then
      mod = 'wool'
      items = {'red', 'blue', 'yellow', 'white', 'orange', 'violet', 'black'}

   elseif node1 == 'vessels:glass_bottle' then
      mod = 'vessels'
      items = {'glass_bottle', 'steel_bottle', 'drinking_glass', 'glass_fragments'}

   elseif node1 == 'beds:bed_bottom' then
      mod = 'beds'
      items = {'bed_bottom', 'fancy_bed_bottom'}

   elseif node1 == node2 then
      return true
   end
   
   for _,item in pairs(items) do
      if mod..":"..item == node2 then
	 return true
      end
   end

   return false
end

sys4_quest.quests = sys4_quest.make_initial_quests()

sys4_quest.current_quest = {}

-- Register the quests defined above
for _,quest in ipairs(sys4_quest.quests) do
   quests.register_quest("sys4_quest:" .. quest[1],
			 { title = quest[2],
			   description = quest[4],
			   max = quest[3],
			   autoaccept = quest[5],
			   callback = sys4_quest.next_quest })
end

local oldpos = {}
minetest.register_on_joinplayer(
   function (player)
      for _,quest in ipairs(sys4_quest.quests) do
	 if not awards.def[quest[1] ].award_req then
	    quests.start_quest(player:get_player_name(), "sys4_quest:"..quest[1])
	 end
      end
      --	quests.show_hud(player:get_player_name())
      oldpos[player:get_player_name()] = player:getpos() -- remember the current location for movement based quests
   end)

-- For quests where you have to dig something, the updates happen here
minetest.register_on_dignode(
   function(pos, oldnode, digger)
      local playern = digger:get_player_name()

      for _,quest in ipairs(sys4_quest.quests) do
	 local questname = quest[1]
	 local award  = awards.def[questname]

	 local node = award.trigger.node

	 if award.trigger.type == "dig" and sys4_quest.isInSameGroup(node, oldnode.name, questname) then
	    if quests.update_quest(playern, "sys4_quest:"..questname, 1) then
	       minetest.after(1, quests.accept_quest, playern, "sys4_quest:"..questname)
	    end
	    
	 end
      end
   end)

minetest.register_on_craft(
   function(itemstack, player, old_craft_grid, craft_inv)
      local playern = player:get_player_name()

      for _,quest in ipairs(sys4_quest.quests) do
	 local questname = quest[1]
	 local award = awards.def[questname]

	 local node = award.trigger.node

	 if award.trigger.type == "craft" and sys4_quest.isInSameGroup(node, itemstack:get_name(), questname) then
	    
	    if quests.update_quest(playern, "sys4_quest:"..questname, itemstack:get_count()) then
	       minetest.after(1, quests.accept_quest, playern, "sys4_quest:"..questname)
	    end
	 end
      end
      
      return nil
   end)


function sys4_quest.register_on_placenode(pos, node, placer)
   local playern = placer:get_player_name()

   for _,quest in ipairs(sys4_quest.quests) do
      local questname = quest[1]
      local award = awards.def[questname]

      local awardnode = award.trigger.node

      if award.trigger.type == "place" and sys4_quest.isInSameGroup(awardnode, node.name, questname) then
	 if quests.update_quest(playern, "sys4_quest:"..questname, 1) then
	    minetest.after(1, quests.accept_quest, playern, "sys4_quest:"..questname)
	 end
      end
   end
end

minetest.register_on_placenode(sys4_quest.register_on_placenode)

local tree_on_place = sys4_achievements.register_on_place
sys4_achievements.register_on_place = function (itemstack, placer, pointed_thing)
   local node = {}
   node.name = itemstack:get_name()
   sys4_quest.register_on_placenode(pointed_thing, node, placer)
   return tree_on_place(itemstack, placer, pointed_thing)
end

local nodes = {
   minetest.registered_nodes["default:tree"],
   minetest.registered_nodes["default:jungletree"],
   minetest.registered_nodes["default:acacia_tree"],
   minetest.registered_nodes["default:pine_tree"],
}

for i=1, #nodes do
   nodes[i].on_place = sys4_achievements.register_on_place
end

--[[minetest.register_chatcommand("next_quest",{
	func = function(name, param) 
		sys4_quest.next_quest(name)
	end
})
--]]
