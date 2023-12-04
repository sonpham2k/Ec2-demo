# config valid for current version and patch releases of Capistrano
lock "~> 3.17.2"
set :application, "Ec2-demo"
set :repo_url, 'git@github.com:sonpham2k/Ec2-demo.git'
set :deploy_to, '/home/ubuntu/Ec2-demo'
set :use_sudo, true
set :branch, 'main'
set :stage, :production
# Default branch is :release
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

set :user,            'ubuntu'
set :puma_threads,    [4, 16]
set :puma_workers,    0
set :rbenv_type, :user
set :rbenv_ruby, '3.2.0'

# Don't change these unless you know what you're doing
set :pty,             true
set :use_sudo,        false
set :deploy_via,      :remote_cache
set :deploy_to,       "/home/#{fetch(:user)}/apps/#{fetch(:application)}"
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.access.log"
set :puma_error_log,  "#{release_path}/log/puma.error.log"
set :ssh_options, {
  forward_agent: true,
  auth_methods: %w[publickey],
  keys: %w[/home/dell/Downloads/EC2_Demo_Son.pem],
  user: "ubuntu",
  verify_host_key: :never,
}
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, true  # Change to false when not using ActiveRecord

## Defaults:
# set :scm,           :git
# set :format,        :pretty
# set :log_level,     :debug
set :keep_releases, 2
# Defaults to nil (no asset cleanup is performed)
# If you use Rails 4+ and you'd like to clean up old assets after each deploy,
# set this to the number of versions to keep
set :keep_assets, 2

## Linked Files & Directories (Default None):
set :linked_files, %w{config/master.key config/database.yml}
set :linked_dirs,  %w{log tmp/pids tmp/cache tmp/sockets vendor/bundle public/system .bundle public/uploads storage}

namespace :puma do
  desc 'Create Directories for Puma Pids and Socket'
  task :make_dirs do
    on roles(:app) do
      execute "mkdir #{shared_path}/tmp/sockets -p"
      execute "mkdir #{shared_path}/tmp/pids -p"
    end
  end

  before :start, :make_dirs
end

namespace :deploy do
  desc "Make sure local git is in sync with remote."
  task :check_revision do
    on roles(:app) do
      unless `git rev-parse HEAD` == `git rev-parse origin/main`
        puts "WARNING: HEAD is not the same as origin/main"
        puts "Run `git push` to sync changes."
        exit
      end
    end
  end

  desc 'Compile assets'
  task :compile_assets => [:set_rails_env] do
    # invoke 'deploy:assets:precompile'
    invoke 'deploy:assets:precompile_local'
  end

  desc 'Initial Deploy'
  task :initial do
    on roles(:app) do
      before 'deploy:restart', 'puma:start'
      invoke 'deploy'
    end
  end

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke 'puma:restart'
    end
  end

  # upload your master.key to the server if it isn't already present
  namespace :check do
    before :linked_files, :set_master_key do
      on roles(:app), in: :sequence, wait: 10 do
        unless test("[ -f #{shared_path}/config/master.key ]")
          upload! 'config/master.key', "#{shared_path}/config/master.key"
          # upload! 'config/credentials/production.key', "#{shared_path}/config/credentials/production.key"
        end
      end
    end
  end

  namespace :assets do
    desc "Precompile assets locally and then rsync to web servers"
    task :precompile_local do
      # compile assets locally
      run_locally do
        execute "RAILS_ENV=#{fetch(:stage)} bundle exec rake assets:precompile"
      end

      # rsync to each server
      dirs = {
        './public/assets/' => 'public/assets/',
        './public/packs/' => 'public/packs/'
      }
      on roles( fetch(:assets_roles, [:web]) ) do
        # this needs to be done outside run_locally in order for host to exist
        dirs.each do |local, remote|
          remote_dir = "#{host.user}@#{host.hostname}:#{release_path}/#{remote}"

          run_locally { execute "rsync -av --delete #{local} #{remote_dir}" }
        end
      end

      # clean up
      run_locally { execute "rm -rf #{dirs.keys.first}" }
    end
  end

  before :starting,     :check_revision
  after  :finishing,    :compile_assets
  after  :finishing,    :cleanup
  after  :finishing,    :restart
end

# ps to | grep puma # Get puma pid
# kill -s SIGUSR2 pid   # Restart puma
# kill -s SIGTERM pid   # Stop puma