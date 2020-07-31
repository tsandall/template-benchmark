package hooks.target.library

##################
# Required Hooks #
##################

autoreject_review[rejection] {
  constraint := data["constraints"][_][_]
  spec := object.get(constraint, "spec", {})
  match := object.get(spec, "match", {})
  not data["inventory"].cluster["v1"]["Namespace"][input.review.namespace]
  not input.review._unstable.namespace
  not input.review.namespace == ""
  has_field(match, "namespaceSelector")
  rejection := {
    "msg": "Namespace is not cached in OPA.",
    "details": {},
    "constraint": constraint,
  }
}

matching_constraints[constraint] {
  constraint := data["constraints"][_][_]
  spec := object.get(constraint, "spec", {})
  match := object.get(spec, "match", {})

  any_kind_selector_matches(match)

  matches_namespaces(match)

  does_not_match_excludednamespaces(match)

  matches_nsselector(match)

  matches_scope(match)

  label_selector := object.get(match, "labelSelector", {})
  any_labelselector_match(label_selector)
}

# Namespace-scoped objects
matching_reviews_and_constraints[[review, constraint]] {
  obj = data["inventory"].namespace[namespace][api_version][kind][name]
  r := make_review(obj, api_version, kind, name)
  review := add_field(r, "namespace", namespace)
  matching_constraints[constraint] with input as {"review": review}
}

# Cluster-scoped objects
matching_reviews_and_constraints[[review, constraint]] {
  obj = data["inventory"].cluster[api_version][kind][name]
  review = make_review(obj, api_version, kind, name)
  matching_constraints[constraint] with input as {"review": review}
}

make_review(obj, api_version, kind, name) = review {
  [group, version] := make_group_version(api_version)
  review := {
    "kind": {"group": group, "version": version, "kind": kind},
    "name": name,
    "object": obj
  }
}

########
# Util #
########

make_group_version(api_version) = [group, version] {
  contains(api_version, "/")
  [group, version] := split(api_version, "/")
}

make_group_version(api_version) = [group, version] {
  not contains(api_version, "/")
  group := ""
  version := api_version
}

add_field(obj, key, value) = ret {
  keys := {k | obj[k]}
  allKeys = keys | {key}
  ret := {k: v | v = object.get(obj, k, value); allKeys[k]}
}

# has_field returns whether an object has a field
has_field(object, field) = true {
  object[field]
}

# False is a tricky special case, as false responses would create an undefined document unless
# they are explicitly tested for
has_field(object, field) = true {
  object[field] == false
}

has_field(object, field) = false {
  not object[field]
  not object[field] == false
}

# get_default returns the value of an object's field or the provided default value.
# It avoids creating an undefined state when trying to access an object attribute that does
# not exist. It considers a null value to be missing.
get_default(object, field, _default) = output {
  has_field(object, field)
  output = object[field]
  output != null
}

get_default(object, field, _default) = output {
  has_field(object, field)
  object[field] == null
  output = _default
}

get_default(object, field, _default) = output {
  has_field(object, field) == false
  output = _default
}

#######################
# Kind Selector Logic #
#######################

any_kind_selector_matches(match) {
  kind_selectors := object.get(match, "kinds", [{"apiGroups": ["*"], "kinds": ["*"]}])
  ks := kind_selectors[_]
  kind_selector_matches(ks)
}

kind_selector_matches(ks) {
  group_matches(ks)
  kind_matches(ks)
}

group_matches(ks) {
  ks.apiGroups[_] == "*"
}

group_matches(ks) {
  ks.apiGroups[_] == input.review.kind.group
}

kind_matches(ks) {
  ks.kinds[_] == "*"
}

kind_matches(ks) {
  ks.kinds[_] == input.review.kind.kind
}

########################
# Scope Selector Logic #
########################

matches_scope(match) {
  not match.scope
}

matches_scope(match) {
  match.scope == "*"
}

matches_scope(match) {
  match.scope == "Namespaced"
  object.get(input.review, "namespace", "") != ""
}

matches_scope(match) {
  match.scope == "Cluster"
  object.get(input.review, "namespace", "") == ""
}

########################
# Label Selector Logic #
########################

# match_expression_violated checks to see if a match expression is violated.
match_expression_violated("In", labels, key, values) = true {
  not labels.key
}

match_expression_violated("In", labels, key, values) = true {
  # values array must be non-empty for rule to be valid
  count(values) > 0
  valueSet := {v | v = values[_]}
  count({labels[key]} - valueSet) != 0
}

# No need to check if labels has the key, because a missing key is automatic non-violation
match_expression_violated("NotIn", labels, key, values) = true {
  # values array must be non-empty for rule to be valid
  count(values) > 0
  valueSet := {v | v = values[_]}
  count({labels[key]} - valueSet) == 0
}

match_expression_violated("Exists", labels, key, values) = true {
  not labels.key
}

match_expression_violated("DoesNotExist", labels, key, values) = true {
  labels.key
}


# Checks to see if a kubernetes LabelSelector matches a given set of labels
# A non-existent selector or labels should be represented by an empty object ("{}")
matches_label_selector(selector, labels) {
  keys := {key | labels[key]}
  matchLabels := object.get(selector, "matchLabels", {})
  satisfiedMatchLabels := {key | matchLabels[key] == labels[key]}
  count(satisfiedMatchLabels) == count(matchLabels)

  matchExpressions := object.get(selector, "matchExpressions", [])

  mismatches := {failure | failure = true; failure = match_expression_violated(
    matchExpressions[i]["operator"],
    labels,
    matchExpressions[i]["key"],
    object.get(matchExpressions[i], "values", []))}

  any(mismatches) == false
}

# object exists, old object is undefined
any_labelselector_match(label_selector) {
  object.get(input.review, "oldObject", {}) == {}
  object.get(input.review, "object", {}) != {}

  obj := object.get(input.review, "object", {})
  metadata := object.get(obj, "metadata", {})
  labels := object.get(metadata, "labels", {})
  matches_label_selector(label_selector, labels)
}

# old object exists, object is undefined
any_labelselector_match(label_selector) {
  object.get(input.review, "oldObject", {}) != {}
  object.get(input.review, "object", {}) == {}

  obj := object.get(input.review, "oldObject", {})
  metadata := object.get(obj, "metadata", {})
  labels := object.get(metadata, "labels", {})
  matches_label_selector(label_selector, labels)
}

# both object and old object are defined
any_labelselector_match(label_selector) {
  object.get(input.review, "oldObject", {}) != {}
  object.get(input.review, "object", {}) != {}

  obj := object.get(input.review, "object", {})
  metadata := object.get(obj, "metadata", {})
  labels := object.get(metadata, "labels", {})

  old_obj := object.get(input.review, "oldObject", {})
  old_metadata := object.get(old_obj, "metadata", {})
  old_labels := object.get(old_metadata, "labels", {})

  all_labels := [labels, old_labels]
  matches := {matches | l := all_labels[_]; matches := matches_label_selector(label_selector, l)}

  any(matches)
}

# neither object nor old object are defined
# this should never happen, included for completeness
any_labelselector_match(label_selector) {
  object.get(input.review, "oldObject", {}) == {}
  object.get(input.review, "object", {}) == {}

  labels = {}
  matches_label_selector(label_selector, labels)
}

############################
# Namespace Selector Logic #
############################

is_ns(kind) {
  kind.group == ""
  kind.kind == "Namespace"
}

get_ns[out] {
  out := input.review._unstable.namespace
}

get_ns[out] {
  not input.review._unstable.namespace
  out := data["inventory"].cluster["v1"]["Namespace"][input.review.namespace]
}

get_ns_name[out] {
  is_ns(input.review.kind)
  out := input.review.object.metadata.name
}

get_ns_name[out] {
  not is_ns(input.review.kind)
  out := input.review.namespace
}

always_match_ns_selectors(match) {
  not is_ns(input.review.kind)
  object.get(input.review, "namespace", "") == ""
}

matches_namespaces(match) {
  not match.namespaces
}

# Always match cluster scoped resources, unless resource is namespace
matches_namespaces(match) {
  match.namespaces
  always_match_ns_selectors(match)
}

matches_namespaces(match) {
  match.namespaces
  not always_match_ns_selectors(match)
  get_ns_name[ns]
  nss := {n | n = match.namespaces[_]}
  count({ns} - nss) == 0
}

does_not_match_excludednamespaces(match) {
  not match.excludedNamespaces
}

# Always match cluster scoped resources, unless resource is namespace
does_not_match_excludednamespaces(match) {
  match.excludedNamespaces
  always_match_ns_selectors(match)
}

does_not_match_excludednamespaces(match) {
  match.excludedNamespaces
  not always_match_ns_selectors(match)
  get_ns_name[ns]
  nss := {n | n = match.excludedNamespaces[_]}
  count({ns} - nss) != 0
}

matches_nsselector(match) {
  not match.namespaceSelector
}

# Always match cluster scoped resources, unless resource is namespace
matches_nsselector(match) {
  match.namespaceSelector
  always_match_ns_selectors(match)
}

matches_nsselector(match) {
  not is_ns(input.review.kind)
  not always_match_ns_selectors(match)
  match.namespaceSelector
  get_ns[ns]
  matches_namespace_selector(match, ns)
}

# if we are matching against a namespace, match against either the old or new object
matches_nsselector(match) {
  is_ns(input.review.kind)
  not always_match_ns_selectors(match)
  match.namespaceSelector
  any_labelselector_match(object.get(match, "namespaceSelector", {}))
}


# Checks to see if a kubernetes NamespaceSelector matches a namespace with a given set of labels
# A non-existent selector or labels should be represented by an empty object ("{}")
matches_namespace_selector(match, ns) {
  metadata := object.get(ns, "metadata", {})
  nslabels := object.get(metadata, "labels", {})
  namespace_selector := object.get(match, "namespaceSelector", {})
  matches_label_selector(namespace_selector, nslabels)
}
