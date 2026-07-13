; ---- Types ----
(type_identifier) @type
(predefined_type) @type.builtin

((identifier) @type
 (#match? @type "^[A-Z]"))

(type_arguments
  "<" @punctuation.bracket
  ">" @punctuation.bracket)

; ---- Variables ----
(required_parameter (identifier) @variable.parameter)
(optional_parameter (identifier) @variable.parameter)

; ---- Keywords ----
[ "abstract"
  "declare"
  "enum"
  "export"
  "implements"
  "interface"
  "keyof"
  "namespace"
  "private"
  "protected"
  "public"
  "type"
  "readonly"
  "override"
  "satisfies"
] @keyword

; ---- Locals (from locals.scm) ----
(required_parameter (identifier) @local.definition)
(optional_parameter (identifier) @local.definition)

; ---- Definitions (from tags.scm) ----
(function_signature
  name: (identifier) @definition.function)

(method_signature
  name: (property_identifier) @definition.method)

(abstract_method_signature
  name: (property_identifier) @definition.method)

(abstract_class_declaration
  name: (type_identifier) @definition.class)

(module
  name: (identifier) @definition.module)

(interface_declaration
  name: (type_identifier) @definition.interface)

(type_annotation
  (type_identifier) @reference.type)

(new_expression
  constructor: (identifier) @reference.class)