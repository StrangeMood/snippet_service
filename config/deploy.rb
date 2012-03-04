set :rack_env, 'production'
set :branch, 'master'
set :application_port, '10001'

set :application, 'snippet_service'
set :host, '174.129.235.5'

set :repository, 'git://github.com/StrangeMood/snippet_service.git'

ssh_options[:keys] = [File.join(ENV['HOME'], '.ssh', 'loki.pem')]
#ssh_options[:forward_agent] = true

set :user, 'ec2-user'

set :scm, 'git'
set :deploy_via, :copy
set :copy_exclude, %w[.git .idea .gitignore Capfile config]

role :app, host
set :deploy_to, "/opt/apps/#{application}"

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
    run "sudo restart #{application}"
  end
  task :stop, :roles => :app do
    run "sudo stop #{application}"
  end
  task :start, :roles => :app do
    run "sudo start #{application}"
  end

  after 'deploy:update_code', 'bundle:install'

  after 'deploy', 'deploy:cleanup', 'deploy:restart'

end

