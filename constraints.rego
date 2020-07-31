package hooks["target"]

violation[response] {
	data.hooks["target"].library.autoreject_review[rejection]
	review := object.get(input, "review", {})
	constraint := object.get(rejection, "constraint", {})
	spec := object.get(constraint, "spec", {})
	enforcementAction := object.get(spec, "enforcementAction", "deny")
	response = {
		"msg": object.get(rejection, "msg", ""),
		"metadata": {"details": object.get(rejection, "details", {})},
		"constraint": constraint,
		"review": review,
		"enforcementAction": enforcementAction,
	}
}

# Finds all violations for a given target
violation[response] {
	data.hooks["target"].library.matching_constraints[constraint]
	review := object.get(input, "review", {})
	inp := {
		"review": review,
		"parameters": object.get(object.get(constraint, "spec", {}), "parameters", {}),
	}
	inventory[inv]
	data.templates["target"][constraint.kind].violation[r] with input as inp with data.inventory as inv
	spec := object.get(constraint, "spec", {})
	enforcementAction := object.get(spec, "enforcementAction", "deny")
	response = {
		"msg": r.msg,
		"metadata": {"details": object.get(r, "details", {})},
		"constraint": constraint,
		"review": review,
		"enforcementAction": enforcementAction,
	}
}


# Finds all violations in the cached state of a given target
audit[response] {
	data.hooks["target"].library.matching_reviews_and_constraints[[review, constraint]]
	inp := {
		"review": review,
		"parameters": object.get(object.get(constraint, "spec", {}), "parameters", {}),
	}
	inventory[inv]
	data.templates["target"][constraint.kind].violation[r] with input as inp with data.inventory as inv
	spec := object.get(constraint, "spec", {})
	enforcementAction := object.get(spec, "enforcementAction", "deny")
	response = {
		"msg": r.msg,
		"metadata": {"details": object.get(r, "details", {})},
		"constraint": constraint,
		"review": review,
		"enforcementAction": enforcementAction,
	}
}

# get_default(data, "external", {}) seems to cause this error:
# "rego_type_error: undefined function data.hooks.<target>.get_default"
inventory[inv] {
	inv = data.external["target"]
}

inventory[{}] {
	not data.external["target"]
}

# get_default returns the value of an object's field or the provided default value.
# It avoids creating an undefined state when trying to access an object attribute that does
# not exist
get_default(object, field, _default) = object[field]

get_default(object, field, _default) = _default {
  not has_field(object, field)
}

has_field(object, field) {
  _ = object[field]
}