name "manila-controller"
description "Manila API and Scheduler Role"
run_list(
  "recipe[manila::api]",
  "recipe[manila::scheduler]",
)
default_attributes
override_attributes
