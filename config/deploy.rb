set :rack_env, 'production'
set :branch, 'master'
set :application_port, '10001'

set :application, 'snippet_service'
set :host, '174.129.235.5'

set :repository, 'git://github.com/StrangeMood/snippet_service.git'

ssh_options[:keys] = [File.join(ENV['HOME'], '.ssh', 'loki.pem')]
#ssh_options[:forward_agent] = true

set :user, 'ec2-user'
set :admin_runner, 'ec2-user'

set :scm, 'git'
set :deploy_via, :copy
set :copy_exclude, %w[.git .idea .gitignore Capfile config]

role :app, host
set :deploy_to, "/opt/apps/#{application}"

set :use_sudo, true
set :sudo_prompt, ''

namespace :deploy do

  task :default do
    transaction do
      update_code
      symlink
    end
  end

  task :update_code, :except => { :no_release => true } do
    on_rollback { sudo "rm -rf #{release_path}; true" }
    strategy.deploy!
  end

  task :restart, :roles => :app do
    sudo "initctl restart #{application}"
  end

  after 'deploy:update_code', 'bundle:install'

  after 'deploy' do
    cleanup
  end

  task :create_deploy_to_with_sudo, :roles => :app do
    sudo "mkdir -p #{deploy_to}"
    sudo "chown #{admin_runner}:#{admin_runner} #{deploy_to}"
  end

  task :write_upstart_script, :roles => :app do
    upstart_script = <<-UPSTART
description "#{application}"

start on startup
stop on shutdown

script
    export RACK_ENV="#{rack_env}"
    cd #{current_path}
    exec sudo -u #{admin_runner} sh -c "bundle exec thin -p #{application_port} -R config.ru start"
end script
respawn
    UPSTART
    put upstart_script, "/tmp/#{application}_upstart.conf"
    sudo "mv /tmp/#{application}_upstart.conf /etc/init/#{application}.conf"
  end

  task :write_nginx_server_conf, :roles => :app do
    server_conf = <<-SERVER_CONF
server {
  listen 80;
  server_name snippets.strangemood.org;

  root /tmp/uploads;

  location /upload {
    upload_pass @backend;
    upload_store /tmp;

    upload_store_access user:rw;

    upload_set_form_field $upload_field_name.name "$upload_file_name";
    upload_set_form_field $upload_field_name.path "$upload_tmp_path";
  }
  location @backend {
    proxy_pass http://localhost:10001;
  }
}
    SERVER_CONF
    put server_conf, "/tmp/#{application}.conf"
    sudo "mv /tmp/#{application}.conf /opt/nginx/conf/servers/#{application}.conf"
  end

end

before 'deploy:setup', 'deploy:create_deploy_to_with_sudo'
after  'deploy:setup', 'deploy:write_upstart_script'
after  'deploy:setup', 'deploy:write_nginx_server_conf'