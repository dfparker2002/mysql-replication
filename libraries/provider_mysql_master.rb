#
# Cookbook Name:: mysql-replication
# Provider:: mysql_master
#
# Copyright 2015 Pavel Yudin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'chef/provider/lwrp_base'

class Chef
  class Provider
    class MysqlMaster < Chef::Provider::LWRPBase
      use_inline_resource if defined?(use_inline_resource)

      include MysqlCookbook::Helpers

      def whytun_supported?
        true
      end

      action :create do
        mysql_config 'master' do
          cookbook 'mysql-replication'
          instance new_resource.name
          source 'master.conf.erb'
          variables id: new_resource.id || node['ipaddress'].split('.').join(''),
                    log_bin: new_resource.log_bin,
                    binlog_format: new_resource.binlog_format,
                    binlog_do_db: new_resource.binlog_do_db,
                    binlog_ignore_db: new_resource.binlog_ignore_db,
                    options: new_resource.options
          action :create
          notifies :restart, "mysql_service[#{new_resource.name}]"
        end

        execute 'Grant permissions' do
          command "echo \" GRANT REPLICATION SLAVE ON *.* TO '#{new_resource.user}'@'#{new_resource.host}'
                   IDENTIFIED BY PASSWORD '#{mysql_password(new_resource.password)}' \" | mysql -S #{mysql_socket}"
          environment ({ 'MYSQL_PWD' => mysql_instance.initial_root_password })
          not_if "echo \"SHOW GRANTS FOR '#{new_resource.user}'@'#{new_resource.host}';\" | mysql -S #{mysql_socket}",
                 environment: {'MYSQL_PWD' => mysql_instance.initial_root_password}
        end
      end

      action :delete do
        mysql_config 'master' do
          instance new_resource.name
          action :delete
        end

        execute 'Remove permissions' do
          command "echo \"DROP USER '#{new_resource.user}'@'#{new_resource.host}';\" | mysql -S #{mysql_socket}"
          environment ({ 'MYSQL_PWD' => mysql_instance.initial_root_password })
          action :run
          only_if "echo \"SHOW GRANTS FOR '#{new_resource.user}'@'#{new_resource.host}';\" | mysql -S #{mysql_socket}",
                  environment: {'MYSQL_PWD' => mysql_instance.initial_root_password}
        end
      end
    end
  end
end
