class_name UIUtils

static func update_list(nodes_original: Array[Node], items: Array[Variant], header: bool, update_func: Callable) -> void:
	# Ignore the header node if it exists
	var nodes: Array[Node] = nodes_original.duplicate()
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
			nodes.append(node)
			n_nodes += 1

		if arity != 3 and arity != 2: push_error(ER_INVALID_ARITY % ["update_list", arity])

		if arity == 3: update_func.call(node, items[i], i)
		elif arity == 2: update_func.call(node, items[i])

static func update_grid(grid: GridContainer, items: Array[Variant], header: bool, update_func: Callable) -> void:
	var cols := grid.columns
	var grid_nodes: Array[Node] = grid.get_children()
	var hdr := 0 if header else -1
	var tmpl := 1 if header else 0
	var n_rows := ceil(grid.get_child_count() / cols)
	var n_items := items.size()
	var arity := update_func.get_argument_count()
	var template_row: Array[Node] = []
	
	if n_rows < (tmpl + 1): push_error(ER_NO_TEMPLATE_ROW % "update_grid"); return

	if arity != 3 and arity != 2: push_error(ER_INVALID_ARITY % ["update_grid", arity])

	for i in range(max(n_rows, n_items)):
		var item: Variant = items[i] if i < n_items else null

		# Get all the nodes for this row
		var row_nodes: Array[Node] = []
		for c in range(0, cols):
			var o := (i * cols) + (tmpl * cols) + c # offset index
			
			if i == 0: template_row.append(grid_nodes[c]) # Fill up the template row
			elif i >= n_items: row_nodes[o].queue_free(); continue # Delete extra nodes

			var node: Node = grid_nodes[o] if o < grid_nodes.size() else null
			if not node:
				node = template_row[c].duplicate()
				grid.add_child(node)

			row_nodes.append(node)

			# If not items, remove the extra nodes

		if arity == 3: update_func.call(row_nodes, item, i)
		elif arity == 2: update_func.call(row_nodes, item)

# Error messages
const ER_NO_TEMPLATE_ROW = "UIUtils.%s(node, item, i): Must have at least one template row, but got an empty array."
const ER_INVALID_ARITY = "UIUtils.%s(node, item, i): must accept 2 or 3 arguments, but got %s"
