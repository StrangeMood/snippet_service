namespace :deploy do
  task :upstart, :roles => :app do
    upstart_script = <<-UPSTART
description "#{application}"

start on startup
stop on shutdown

script
    export RACK_ENV="#{rack_env}"
    cd #{current_path}
    exec sudo -u nobody sh -c "bundle exec thin -p #{application_port} -R config.ru start -l #{deploy_to}/shared/logs/out.log"
end script
respawn
    UPSTART
    put upstart_script, "/tmp/#{application}_upstart.conf"
    run "sudo mv /tmp/#{application}_upstart.conf /etc/init/#{application}.conf"
  end

  task :server_conf, :roles => :app do
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
    run "sudo mv /tmp/#{application}.conf /opt/nginx/conf/servers/#{application}.conf"
  end

  before 'deploy:setup' do
    run "sudo mkdir -p #{deploy_to}"
    run "sudo chown #{user}:#{user} #{deploy_to}"
  end

  after 'deploy:setup' do
    run "mkdir -p #{deploy_to}/shared/logs"
    run "sudo chown nobody:nobody #{deploy_to}/shared/logs"
  end

  after  'deploy:setup', 'deploy:upstart'
  after  'deploy:setup', 'deploy:server_conf'
end