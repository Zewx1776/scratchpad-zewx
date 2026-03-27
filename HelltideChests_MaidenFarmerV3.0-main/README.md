# HelltideChests_MaidenFarmerV3.0

Route Optimizer
The Route Optimizer (route_optimizer.lua) is a system that:

Path Management:
Tracks whether an initial loop has been completed
Manages optimized routes for chest farming
Keeps count of missed chests
Can determine if the player is within city boundaries
Key Functions:
is_in_city(): Checks if player is within a 20-unit radius of the first waypoint
plan_optimized_route(): Creates efficient routes to collect missed chests
complete_initial_loop(): Marks the completion of the initial farming loop
reset(): Resets all optimization parameters to their default state
Route Optimization Features:
Can reverse waypoint direction when needed
Calculates the best path for collecting missed chests
Maintains state of current route optimization
Vendor Manager
While the complete vendor_manager.lua file isn't available, based on the expert's information, it handles:

Vendor Interactions:
Manages movement towards vendors
Handles vendor-related interactions
Provides visual feedback about current vendor targets
Key Features:
Automated movement to vendor locations
Rendering of vendor-related information
Management of vendor-related activities
Integration:
Works in conjunction with the route optimization system
Helps maintain efficient farming routes while managing inventory
Both systems work together to create an efficient farming experience by:

Optimizing paths between chests and vendors
Managing inventory through smart vendor visits
Maintaining efficient movement patterns
Providing visual feedback to the user
Handling both farming and inventory management needs automatically
This combination allows for extended farming sessions with minimal manual intervention while maintaining optimal efficiency.

Stashing Requirements:
Auto stash must be enabled (menu.auto_stash_boss_materials:get())
Item must be a valid boss material
Stack must be exactly 50 items
Process Flow
When inventory needs management:
Plugin disables main functionality
Teleports to Three of Whispers
Processes items in order: stash boss materials → stash items → salvage → repair → sell
After processing:
Returns to previous location
Resumes main functionality
This system ensures efficient inventory management while maintaining valuable items and materials through specific criteria for selling and stashing.
