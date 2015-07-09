#
# Copyright 2015, SUSE LINUX GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class ManilaService < ServiceObject
  def initialize(thelogger)
    @bc_name = "manila"
    @logger = thelogger
  end

  # Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  class << self
  def role_constraints
    {
      "manila-controller" => {
        "unique" => false,
        "count" => 1,
        "cluster" => true,
        "admin" => false,
        "exclude_platform" => {
          "windows" => "/.*/"
        },
      },
      "manila-share" => {
        "unique" => false,
        "count" => -1,
        "admin" => false,
        "exclude_platform" => {
          "windows" => "/.*/"
        }
      }
    }
  end
end

  def proposal_dependencies(role)
    answer = []
    # NOTE(toabctl): nova, cinder, glance and neutron are just needed
    # for the generic driver. So this could be optional depending on the used
    # driver
    deps = ["database", "keystone", "rabbitmq",
            "nova", "cinder", "glance", "neutron"]
    deps.each do |dep|
      answer << {
        "barclamp" => dep,
        "inst" => role.default_attributes[@bc_name]["#{dep}_instance"]
      }
    end
    answer
  end

  def create_proposal
    @logger.debug("Manila create_proposal: entering")
    base = super

    nodes = NodeObject.all
    controllers = select_nodes_for_role(
      nodes, "manila-controller", "controller") || []
    # FIXME(toabctl): I think there no reason to use storage nodes
    # for manila-share
    storage = select_nodes_for_role(
      nodes, "manila-share", "storage") || []

    base["deployment"][@bc_name]["elements"] = {
      "manila-controller" => controllers.empty? ? [] : [controllers.first.name],
      "manila-share" => storage.map(&:name)
    }

    base["attributes"][@bc_name]["database_instance"] =
      find_dep_proposal("database")
    base["attributes"][@bc_name]["rabbitmq_instance"] =
      find_dep_proposal("rabbitmq")
    base["attributes"][@bc_name]["keystone_instance"] =
      find_dep_proposal("keystone")

    base["attributes"][@bc_name]["service_password"] = random_password
    base["attributes"][@bc_name][:db][:password] = random_password

    @logger.debug("Manila create_proposal: exiting")
    base
  end

  def validate_proposal_after_save(proposal)
    validate_one_for_role proposal, "manila-controller"
    validate_at_least_n_for_role proposal, "manila-share", 1
    super
  end

  def apply_role_pre_chef_call(_old_role, _role, all_nodes)
    @logger.debug("Manila apply_role_pre_chef_call: "\
                  "entering #{all_nodes.inspect}")

    # Make sure the bind hosts are in the admin network
    all_nodes.each do |n|
      node = NodeObject.find_node_by_name n

      admin_address = node.get_network_by_type("admin")["address"]
      node.crowbar[:manila] = {} if node.crowbar[:manila].nil?
      node.crowbar[:manila][:api_bind_host] = admin_address

      node.save
    end
    @logger.debug("Manila apply_role_pre_chef_call: leaving")
  end
end
