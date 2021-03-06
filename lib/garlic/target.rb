require 'shell'

module Garlic
  class Target
    attr_reader :garlic, :path, :name, :rails_repo_name, :tree_ish

    def initialize(garlic, options = {})
      @garlic = garlic
      @tree_ish = Repo.tree_ish(options) || 'origin/master'
      @rails_repo_name = options[:rails] || 'rails'
      @path = options[:path] or raise ArgumentError, "Target requires a :path"
      @path = File.expand_path(@path)
      @name = options[:name] || File.basename(@path)
      @prepare = options[:prepare]
      @run = options[:run]
    end
    
    def prepare
      puts "\nPreparing target #{name} (#{tree_ish})"
      install_rails
      runner.run(&@prepare) if @prepare
    end
    
    def run
      runner.run(&@run) if @run
    end
    
    def rails_sha
      read_sha('vendor/rails')
    end
    
    def shell
      unless @shell
        @shell = Shell.new
        @shell.verbose = false
        @shell.cd path
      end
      @shell
    end
    
  private
    def runner
      @runner ||= Target::Runner.new(self)
    end
    
    def read_sha(install_path)
      File.read(File.join(path, install_path, '.git_sha')) rescue nil
    end
    
    def write_sha(install_path, sha)
      File.open(File.join(path, install_path, '.git_sha'), 'w+') {|f| f << sha}
    end

    def install_rails
      rails_repo = garlic.repo(rails_repo_name)
      rails_repo.checkout(tree_ish)
      if File.exists?(path)
        puts "Rails app for #{name} exists"
      else
        puts "Creating rails app for #{name}..."
        `ruby #{rails_repo.path}/railties/bin/rails #{path}`
      end
      install_dependency(rails_repo, 'vendor/rails') { `rake rails:update` }
    end

    def install_dependency(repo, install_path = ".", options = {}, &block)
      repo = garlic.repo(repo) unless repo.is_a?(Repo)
      tree_ish = Repo.tree_ish(options)
      
      if options[:clone]
        if Repo.path?(install_path)
          puts "#{install_path} exists, and is a repo"
          cd(install_path) { `git fetch origin` }
        else
          puts "cloning #{repo.name} to #{install_path}"
          repo.clone_to(File.join(path, install_path))
        end
        cd(install_path) { `git checkout #{tree_ish || repo.head_sha}` }
      
      else
        old_tree_ish = repo.head_sha
        repo.checkout(tree_ish) if tree_ish       
        if read_sha(install_path) == repo.head_sha
          puts "#{install_path} is up to date at #{tree_ish || repo.head_sha[0..6]}"
        else
          puts "#{install_path} needs update to #{tree_ish || repo.head_sha[0..6]}, exporting archive from #{repo.name}..."
          repo.export_to(File.join(path, install_path))
          cd(path) { garlic.instance_eval(&block) } if block_given?
          write_sha(install_path, repo.head_sha)
        end
        repo.checkout(old_tree_ish) if tree_ish
      end
    end
    
    
    class Runner
      attr_reader :target

      def initialize(target)
        @target = target
      end
      
      def run(&block)
        cd target.path do
          instance_eval(&block)
        end
      end
      
      def method_missing(method, *args, &block)
        target.garlic.send(method, *args, &block)
      end

      def respond_to?(method)
        super(method) || target.garlic.respond_to?(method)
      end

      def plugin(plugin, options = {}, &block)
        target.send(:install_dependency, plugin, "vendor/plugins/#{options[:as] || plugin}", options, &block)
      end

      def dependency(repo, dest, options = {}, &block)
        target.send(:install_dependency, repo, dest, options, &block)
      end
    end
  end
end