class_name JamminList

# In Godot's 2D UI, I often find myself needing to dynamically add and subtract rows of
# data (such as in a multiplayer lobby system, an inventory system, etc).
#
# JamminList makes updating lists and grids really easy! Build your UI and provide a
# template row (and an optional header row), along with a function to update every item
# in the list/grid, and then let JamminList do the rest.
#
# See more info here: https://gist.github.com/jamonholmgren/a584c1b55b2fd21b7a260b5f3c0b0b6f

static func update_list(node_parent: Node, items: Array[Variant], header: bool, update_func: Callable) -> void:
	# Ignore the header node if it exists
	var nodes: Array[Node] = node_parent.get_children().duplicate()
	if header: nodes.erase(nodes[0])
	
	var template_row := nodes[0]
	template_row.visible = items.size() > 0
	var n_nodes := nodes.size()
	var n_items := items.size()
	var arity := update_func.get_argument_count()
	
	if n_nodes < 1: push_error(ER_NO_TEMPLATE_ROW % "update_list"); return
	
	# Update existing rows and add new ones, and delete extra rows (down to 1; leave at least the template row)
	for i in range(max(n_nodes, n_items)):
		# No rows to show? Hide the template row
		if i == 0 and n_items == 0: continue # Don't delete the template row!

		# Out of items? Delete the extra node(s)
		if i >= n_items: nodes[i].queue_free(); continue

		var node := nodes[i] if i < n_nodes else null
		if not node:
			node = template_row.duplicate()
			node_parent.add_child(node)

		assert(arity == 3 or arity == 2, ER_INVALID_ARITY % ["update_list", arity])

		if arity == 3: update_func.call(node, items[i], i)
		elif arity == 2: update_func.call(node, items[i])

static func update_grid(grid: GridContainer, items: Array[Variant], header: bool, update_func: Callable) -> void:
	var cols := grid.columns
	var grid_nodes: Array[Node] = grid.get_children().duplicate()

	# Remove the header nodes from consideration
	if header: for c in range(cols): grid_nodes.erase(grid_nodes[0])

	var n_rows := ceil(grid_nodes.size() / cols)
	var n_items := items.size()
	var arity := update_func.get_argument_count()
	var template_row: Array[Node] = []
	
	assert(n_rows >= 1, ER_NO_TEMPLATE_ROW % "update_grid")
	assert(arity == 3 or arity == 2, ER_INVALID_ARITY % ["update_grid", arity])

	for i in range(max(n_rows, n_items)):
		var item: Variant = items[i] if i < n_items else null
		
		# Get all the nodes for this row
		var row_nodes: Array[Node] = []
		for c in range(cols):
			var o := (i * cols) + c # offset index
			
			# Show/hide the node based on whether the item is null
			grid_nodes[o].visible = item != null

			if i == 0: template_row.append(grid_nodes[c]) # Fill up the template row
			elif i >= n_items: row_nodes[o].queue_free(); continue # Delete extra nodes

			var node: Node = grid_nodes[o] if o < grid_nodes.size() else null
			if not node:
				node = template_row[c].duplicate()
				grid.add_child(node)

			row_nodes.append(node)

		if not item: continue
		if arity == 3: update_func.call(row_nodes, item, i)
		elif arity == 2: update_func.call(row_nodes, item)

# Error messages
const ER_NO_TEMPLATE_ROW = "UIUtils.%s(node, item, i): Must have at least one template row, but got an empty array."
const ER_INVALID_ARITY = "UIUtils.%s(node, item, i): must accept 2 or 3 arguments, but got %s"

