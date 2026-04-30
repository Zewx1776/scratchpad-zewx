local Settings = require("src.settings")
local ItemManager = require("src.item_manager")
local Renderer = require("src.renderer")
local GUI = require("gui")
local Utils = require("utils.utils")
local explorerlite = require "core.explorerlite"

local function handle_loot(wanted_item)
   if wanted_item then
      if Utils.distance_to(wanted_item) > 2 then
         local item_position = wanted_item:get_position()
         -- pathfinder.request_move(item_position)
         explorerlite:set_custom_target(item_position)
         explorerlite:move_to_target()
      else
         interact_object(wanted_item)
      end
   end
end

local function main_pulse()
   if not get_local_player() then return end

   Settings.update()

   if not Settings.get().enabled then return end

   if not Settings.should_execute() then return end

   orbwalker.set_auto_loot_toggle(false)

   local loot_priority = GUI.elements.general.loot_priority_combo:get()

   if loot_priority == 0 then
      local wanted_item = ItemManager.get_nearby_item()
      if wanted_item then
         Settings.get().looting = true
         handle_loot(wanted_item)
      else
         Settings.get().looting = false
      end
   elseif loot_priority == 1 then
      local best_item_data = ItemManager.get_best_item()
      if best_item_data then
         Settings.get().looting = true
         handle_loot(best_item_data.Item)
      else
         Settings.get().looting = false
      end
   end
end

-- Set Global access for other plugins
LooteerPlugin = {
   getSettings = function (setting)
      if Settings.get()[setting] then
          return Settings.get()[setting]
      else
          return nil
      end
  end,
  setSettings = function (setting, value)
      if Settings.get()[setting] then
          Settings.get()[setting] = value
          return true
      else
          return false
      end
  end,
}

on_update(main_pulse)
on_render_menu(GUI.render)
on_render(Renderer.draw_stuff)