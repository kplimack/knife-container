#
# Copyright:: Copyright (c) 2014 Chef Software Inc.
# License:: Apache License, Version 2.0
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
#

require 'chef/knife'
require 'knife-container/command'

class Chef
  class Knife
    class DockerInit < Knife

      include KnifeContainer::Command

      banner "knife docker init REPO/NAME [options]"

      option :base_image,
        :short => "-f [REPO/]IMAGE[:TAG]",
        :long => "--from [REPO/]IMAGE[:TAG]",
        :description => "The image to use for the FROM value in your Dockerfile",
        :proc => Proc.new { |f| Chef::Config[:knife][:docker_image] = f },
        :default => "chef/ubuntu_12.04"

      option :run_list,
        :short => "-r RunlistItem,RunlistItem...,",
        :long => "--run-list RUN_LIST",
        :description => "Comma seperated list of roles/recipes to apply to your Docker image",
        :default => [],
        :proc => Proc.new { |o| o.split(/[\s,]+/) }

      option :local_mode, 
        :boolean => true,
        :short => "-z",
        :long => "--local-mode",
        :description => "Include and use a local chef repository to build the Docker image"

      option :generate_berksfile,
        :short => "-b",
        :long => "--berksfile",
        :description => "Generate a Berksfile based on the run_list provided",
        :boolean => true,
        :default => false

      option :validation_key,
        :long => "--validation-key PATH",
        :description => "The path to the validation key used by the client, typically a file named validation.pem"

      option :validation_client_name,
        :long => "--validation-client-name NAME",
        :description => "The name of the validation client, typically a client named chef-validator"

      option :chef_server_url,
        :long => "--server-url URL",
        :description => "Chef Server URL"

      option :cookbook_path,
        :long => "--cookbook-path PATH[:PATH]",
        :description => "A colon-seperated path to look for cookbooks in",
        :proc => Proc.new { |o| o.split(':') }

      option :role_path,
        :long => "--role-path PATH[:PATH]",
        :description => "A colon-seperated path to look for roles in",
        :proc => Proc.new { |o| o.split(':') }

      option :node_path,
        :long => "--node-path PATH[:PATH]",
        :description => "A colon-seperated path to look for node objects in",
        :proc => Proc.new { |o| o.split(':') }

      option :environment_path,
        :long => "--environment-path PATH[:PATH]",
        :description => "A colon-seperated path to look for environments in",
        :proc => Proc.new { |o| o.split(':') }

      option :dockerfiles_path,
        :short => "-d PATH",
        :long => "--dockerfiles-path PATH",
        :proc => Proc.new { |d| Chef::Config[:knife][:dockerfiles_path] = d }

      
      def run
        read_and_validate_params
        set_config_defaults
        setup_context
        chef_runner.converge
      end

      def read_and_validate_params
        if @name_args.length < 1
          ui.error("You must specify a Dockerfile name")
          show_usage
          exit 1
        end
        if config[:generate_berksfile]
          begin
            require 'berkshelf'
          rescue LoadError
            ui.error("You must have the Berkshelf gem installed to use the Berksfile flag.")
            show_usage
            exit 1
          else
            # other exception
          ensure
            # always executed
          end
        end
      end

      def set_config_defaults
        %w(
          validation_key
          validation_client_name
          chef_server_url
          cookbook_path
          node_path
          role_path
          environment_path
        ).each do |var|
          config[:"#{var}"] ||= Chef::Config[:"#{var}"]
        end

        config[:dockerfiles_path] = File.join(Chef::Config[:chef_repo_path], "dockerfiles")
      end

      def setup_context
        generator_context.dockerfile_name = @name_args[0]
        generator_context.dockerfiles_path = config[:dockerfiles_path]
        generator_context.base_image = config[:base_image]
        generator_context.chef_client_mode = chef_client_mode
        generator_context.run_list = config[:run_list]
        generator_context.cookbook_path = config[:cookbook_path]
        generator_context.role_path = config[:role_path]
        generator_context.node_path = config[:node_path]
        generator_context.environment_path = config[:environment_path]
        generator_context.chef_server_url = config[:chef_server_url]
        generator_context.validation_key = config[:validation_key]
        generator_context.validation_client_name = config[:validation_client_name]
        generator_context.first_boot = first_boot_content
        generator_context.berksfile = config[:berksfile]
      end

      def recipe
        "docker_init"
      end

      def first_boot_content
        first_boot = {}
        first_boot['run_list'] = config[:run_list]
        first_boot.to_json
      end

      def chef_client_mode
        config[:local_mode] ? "zero" : "client"
      end

    end
  end
end
