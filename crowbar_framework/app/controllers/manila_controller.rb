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

class ManilaController < PacemakerServiceObject
  # Controller for Manila barclamp

  # Turn off multi proposal support till it really works and people ask for it.
  def self.allow_multiple_proposals?
    false
  end

  def apply_role_pre_chef_call(_, role, all_nodes)
    @logger.debug(
      "Manila apply_role_pre_chef_call: entering #{all_nodes.inspect}")

    server_elements, server_nodes, ha_enabled = role_expand_elements(
      role, "manila-controller")

    vip_networks = ["admin", "public"]

    dirty = prepare_role_for_ha_with_haproxy(
      role, ["manila", "ha", "enabled"], ha_enabled, server_elements,
      vip_networks)
    role.save if dirty

    unless all_nodes.empty? || server_elements.empty?
      net_svc = NetworkService.new @logger
      # All nodes must have a public IP, even if part of a cluster; otherwise
      # the VIP can't be moved to the nodes
      server_nodes.each do |node|
        net_svc.allocate_ip "default", "public", "host", node
      end

      allocate_virtual_ips_for_any_cluster_in_networks_and_sync_dns(
        server_elements, vip_networks)
    end

    @logger.debug("Manila apply_role_pre_chef_call: leaving")
  end

  protected

  def initialize_service
    @service_object = ManilaService.new logger
  end
end
