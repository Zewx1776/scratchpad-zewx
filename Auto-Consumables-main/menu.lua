local plugin_label = "AUTO_CONSUMABLES_S11_EXCURSE_SALAD"
local menu = {}
local options = require("data.consumable_options")

menu.elements = {
  main_tree = tree_node:new(0),
  main_toggle = checkbox:new(false, get_hash(plugin_label .. "_main_toggle")),
  require_target_toggle = checkbox:new(true, get_hash(plugin_label .. "_require_target_toggle")),
  debug_toggle = checkbox:new(false, get_hash(plugin_label .. "_debug_toggle")),

  elixir_tree = tree_node:new(1),
  incense_tree = tree_node:new(1),

  basic_elixir_combo = combo_box:new(0, get_hash(plugin_label .. "_basic_elixir_combo")),
  basic_elixir_toggle = checkbox:new(false, get_hash(plugin_label .. "_basic_elixir_toggle")),

  advanced_elixir_combo = combo_box:new(0, get_hash(plugin_label .. "_advanced_elixir_combo")),
  advanced_elixir_toggle = checkbox:new(false, get_hash(plugin_label .. "_advanced_elixir_toggle")),

  core_stat_incense_combo = combo_box:new(0, get_hash(plugin_label .. "_core_stat_incense_combo")),
  core_stat_incense_toggle = checkbox:new(false, get_hash(plugin_label .. "_core_stat_incense_toggle")),

  defensive_incense_combo = combo_box:new(0, get_hash(plugin_label .. "_defensive_incense_combo")),
  defensive_incense_toggle = checkbox:new(false, get_hash(plugin_label .. "_defensive_incense_toggle")),

  resistance_incense_combo = combo_box:new(0, get_hash(plugin_label .. "_resistance_incense_combo")),
  resistance_incense_toggle = checkbox:new(false, get_hash(plugin_label .. "_resistance_incense_toggle")),
}

function menu.render()
  if not menu.elements.main_tree:push("Auto Consumables - S11 - Excurse+Salad") then
    return
  end

  menu.elements.main_toggle:render("Enable", "Toggles Consumable Buffs on/off")
  if not menu.elements.main_toggle:get() then
    menu.elements.main_tree:pop()
    return
  end

  -- Target requirement checkbox
  menu.elements.require_target_toggle:render("Require Target", "Only use consumables when enemies are nearby, Switch it off for bossing")
  menu.elements.debug_toggle:render("Debug Mode", "Enables debug logging for consumable usage")

  if menu.elements.elixir_tree:push("Elixirs") then
    menu.elements.basic_elixir_combo:render("Basic Elixirs", options.basic_elixir_names, "Which basic elixir do you want to use?")
    menu.elements.basic_elixir_toggle:render("Enable Basic Elixirs", "Toggles Basic Elixir usage on/off")
    
    menu.elements.advanced_elixir_combo:render("Advanced Elixirs", options.advanced_elixir_names, "Which advanced elixir do you want to use?")
    menu.elements.advanced_elixir_toggle:render("Enable Advanced Elixirs", "Toggles Advanced Elixir usage on/off")
    menu.elements.elixir_tree:pop()
  end

  if menu.elements.incense_tree:push("Incenses") then
    menu.elements.core_stat_incense_combo:render("Core Stat Incenses", options.core_stat_incense_names, "Which core stat incense do you want to use?")
    menu.elements.core_stat_incense_toggle:render("Enable Core Stat Incense", "Toggles Core Stat Incense usage on/off")
    
    menu.elements.defensive_incense_combo:render("Defensive Incenses", options.defensive_incense_names, "Which defensive incense do you want to use?")
    menu.elements.defensive_incense_toggle:render("Enable Defensive Incense", "Toggles Defensive Incense usage on/off")
    
    menu.elements.resistance_incense_combo:render("Resistance Incenses", options.resistance_incense_names, "Which resistance incense do you want to use?")
    menu.elements.resistance_incense_toggle:render("Enable Resistance Incense", "Toggles Resistance Incense usage on/off")
    menu.elements.incense_tree:pop()
  end

  menu.elements.main_tree:pop()
end

return menu