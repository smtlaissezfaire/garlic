# typical shoulda garlic configuration

garlic do
  # this plugin
  repo "#{plugin}", :path => '.'
  
  # other repos
  repo "rails", :url => "git://github.com/rails/rails"
  repo "shoulda", :url => "git://github.com/thoughtbot/shoulda"
  
  # targets
  target "edge", :branch => 'origin/master'
  target "2.1", :branch => "origin/2-1-stable"
  target "2.0", :branch => "origin/2-0-stable"
  target "1.2", :branch => "origin/1-2-stable"
  
  # all targets
  all_targets do
    prepare do
      plugin "#{plugin}", :clone => true # so we can work in targets
      plugin "shoulda"
    end
    
    run do
      cd "vendor/plugins/#{plugin}" do
        sh "rake"
      end
    end
  end
end