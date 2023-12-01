# config valid for current version and patch releases of Capistrano

# config valid for current version and patch releases of Capistrano
lock "~> 3.18.0"
set :application, "Ec2-demo"
set :repo_url, 'git@github.com:sonpham2k/Ec2-demo.git'
set :deploy_to, '/home/ubuntu/Ec2-demo'
set :use_sudo, true
set :branch, 'main'
set :stage, :production
set :linked_files, %w{config/master.key config/database.yml}
set :rails_env, 'production'
set :keep_releases, 2
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'vendor/bundle', 'public/system')
set :linked_files, %w{config/database.yml config/master.key}

set :rbenv_type, :user
set :rbenv_ruby, '3.2.0'
# Default branch is :master
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.access.log"
set :puma_error_log,  "#{release_path}/log/puma.error.log"
# set :ssh_options, { forward_agent: true, user: fetch(:user), keys: %w(~/.ssh/id_rsa) }
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