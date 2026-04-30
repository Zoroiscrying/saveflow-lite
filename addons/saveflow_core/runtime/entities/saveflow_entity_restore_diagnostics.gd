extends RefCounted

const ISSUE_CODES := [
	"INVALID_DESCRIPTOR",
	"MISSING_TYPE_KEY",
	"MISSING_PERSISTENT_ID",
	"FACTORY_NOT_FOUND",
	"EXISTING_ENTITY_NOT_FOUND",
	"SPAWN_RETURNED_NULL",
	"ENTITY_GRAPH_APPLY_FAILED",
]

const ISSUE_MEANINGS := {
	"INVALID_DESCRIPTOR": "The restore input is not a dictionary or SaveFlowEntityDescriptor.",
	"MISSING_TYPE_KEY": "The descriptor or identity does not provide a usable type_key.",
	"MISSING_PERSISTENT_ID": "The descriptor or identity does not provide a usable persistent_id.",
	"FACTORY_NOT_FOUND": "No registered factory can restore that type_key.",
	"EXISTING_ENTITY_NOT_FOUND": "Restore policy is Apply Existing, but the matching node is absent.",
	"SPAWN_RETURNED_NULL": "The factory route exists, but spawning did not return an entity node.",
	"ENTITY_GRAPH_APPLY_FAILED": "The entity spawned or reused, but its nested save graph failed to apply.",
}

const ISSUE_NEXT_ACTIONS := {
	"INVALID_DESCRIPTOR": "Check that saved entity descriptors are dictionaries or SaveFlowEntityDescriptor values.",
	"MISSING_TYPE_KEY": "Set explicit type_key values that match entity factory routes.",
	"MISSING_PERSISTENT_ID": "Set stable persistent_id values on SaveFlowIdentity nodes or descriptors.",
	"FACTORY_NOT_FOUND": "Assign or register an entity factory that supports this type_key.",
	"EXISTING_ENTITY_NOT_FOUND": "Use Create Missing, or make sure the entity exists before loading.",
	"SPAWN_RETURNED_NULL": "Check the factory prefab, target container, and spawn logic.",
	"ENTITY_GRAPH_APPLY_FAILED": "Inspect the entity's nested Source payload and apply failure.",
}


static func known_issue_codes() -> PackedStringArray:
	return PackedStringArray(ISSUE_CODES)


static func get_issue_meaning(code: String) -> String:
	return String(ISSUE_MEANINGS.get(code, "Unknown runtime entity restore issue."))


static func get_issue_next_action(code: String) -> String:
	return String(ISSUE_NEXT_ACTIONS.get(code, "Inspect entity_restore_issues for details."))
