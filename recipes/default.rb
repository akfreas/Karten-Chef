#
# Cookbook Name:: karten
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
#

#include_recipe "database::postgresql"
app_config = data_bag_item('apps', node['deploy']['data_bag'])
socket_path = "unix:/tmp/gunicorn_#{node['deploy']['app']['name']}.sock"

include_recipe "supervisor"
postgres_connection = {:host => 'localhost', :username => "postgres"}

execute "apt-get update" do
  command "apt-get update"
  ignore_failure true
  action :run
end

supervisor_service node['deploy']['app']['name'] do
    command "#{node['deploy']['deploy_to']}/shared/env/bin/gunicorn  #{node['deploy']['app_name']}.wsgi -b #{socket_path} --pythonpath #{node['deploy']['deploy_to']}/current/#{node['deploy']['app_name']} --workers=2 --timeout=10"
    user node['deploy']['user']
    autorestart true
    autostart true
    priority 998
    action :enable
end
 
postgresql_database app_config['database']['name'] do
    connection postgres_connection
    action :create
end

postgresql_database_user app_config['database']['username'] do
    password app_config['database']['password']
    connection postgres_connection
    action :create
end
 
application node['deploy']['app']['name'] do
    path node['deploy']['deploy_to']
    owner node['user']
    group node['group']
    repository node['deploy']['repository']
    revision node['deploy']['branch']
    migrate true
    migration_command "#{::File.join(path, "shared", "env", "bin", "python")} #{node['deploy']['app_name']}/manage.py syncdb --noinput"
    deploy_key node['deploy_key']
    before_migrate do
        pip_cmd = ::File.join(shared_path, 'env', 'bin', 'pip')
        execute "#{pip_cmd} install --source=#{Dir.tmpdir} -r #{release_path}/requirements.pip" do
            cwd release_path
            user new_resource.owner
            user new_resource.group
        end
        template "#{release_path}/#{node['deploy']['app_name']}/local_settings.py" do
            source "local_settings.py.erb"
            variables(
                :database => "karten",
                :engine => "postgresql_psycopg2",
                :username => app_config['database']['username'],
                :password => app_config['database']['password'],
            )
        end
    end
    before_deploy do
        python_virtualenv ::File.join(shared_path, 'env') do
            path ::File.join(shared_path, 'env')
            owner new_resource.owner
            group new_resource.group
            action :create
        end

        template "/etc/nginx/sites-enabled/default" do
            source "nginx-default.erb"
            owner "root"
            group "root"
            variables(
                :app_name => node['deploy']['app_name'],
                :app_home => release_path,
                :shared_path => shared_path,
                :staticfiles_root => node['deploy']['staticfiles_root'],
                :socket_path => socket_path,
                :domain => node['deploy']['domain'],
            )
        end
    end
    restart_command do

        supervisor_service node['deploy']['app']['name'] do
            action :start
        end

        service "nginx" do
            action :reload
        end
    end
end

def install_packages
  python_virtualenv new_resource.virtualenv do
    path new_resource.virtualenv
    owner new_resource.owner
    group new_resource.group
    action :create
  end

  new_resource.packages.each do |name, ver|
    python_pip name do
      version ver if ver && ver.length > 0
      virtualenv new_resource.virtualenv
      user new_resource.owner
      group new_resource.group
      action :install
    end
  end
end


